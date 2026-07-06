#!/bin/bash

# =============================================================
# update.sh - Pull latest code from GitHub and re-deploy filemd
# Usage: bash update.sh
#
# What it does:
#   1. Pull latest code from origin/<branch>
#   2. Re-build backend  (composer install, artisan optimize)
#   3. Re-build frontend (npm ci, vite build)
#   4. Re-deploy to Azure (App Service + Static Web Apps)
#   5. Health check
# =============================================================

set -euo pipefail

CONFIG_FILE=".update.conf"
LOG_FILE="update.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { local msg="[$(date '+%H:%M:%S')] [INFO]  $1"; echo -e "${GREEN}${msg}${NC}"; echo "$msg" >> "$LOG_FILE"; }
warn()    { local msg="[$(date '+%H:%M:%S')] [WARN]  $1"; echo -e "${YELLOW}${msg}${NC}"; echo "$msg" >> "$LOG_FILE"; }
error()   { local msg="[$(date '+%H:%M:%S')] [ERROR] $1"; echo -e "${RED}${msg}${NC}";    echo "$msg" >> "$LOG_FILE"; }
section() { echo ""; echo -e "${CYAN}======================================${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}======================================${NC}"; echo ""; }

# ── Input helpers ─────────────────────────────────────────────
prompt_required() {
  local var_name="$1" prompt_text="$2" current_val="${!1:-}" input
  while true; do
    if [ -n "$current_val" ]; then
      read -rp "$prompt_text [$current_val]: " input
      input="${input:-$current_val}"
    else
      read -rp "$prompt_text: " input
    fi
    [ -n "$input" ] && { eval "$var_name=\"$input\""; break; } || warn "Cannot be empty."
  done
}

# ── Config ────────────────────────────────────────────────────
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    log "Config loaded from $CONFIG_FILE"
  fi

  # Also load deploy config for Azure details if available
  if [ -f ".deploy.conf" ]; then
    source ".deploy.conf"
    log "Azure config loaded from .deploy.conf"
  fi
}

save_config() {
  cat > "$CONFIG_FILE" <<EOF
REPO_URL="${REPO_URL:-}"
BRANCH="${BRANCH:-}"
SKIP_AZURE="${SKIP_AZURE:-false}"
EOF
  log "Config saved to $CONFIG_FILE"
}

# ── Prereq checks ─────────────────────────────────────────────
check_prerequisites() {
  local missing=0
  for cmd in git php composer node npm; do
    command -v "$cmd" &>/dev/null || { error "$cmd not found."; missing=1; }
  done
  [ "$missing" -eq 1 ] && { error "Install missing tools and re-run."; exit 1; }
}

# ── Git pull ──────────────────────────────────────────────────
pull_latest() {
  section "Pulling Latest Code"

  cd "$SCRIPT_DIR"

  if [ ! -d ".git" ]; then
    log "No .git found — cloning fresh..."
    prompt_required REPO_URL "GitHub repo URL (https or ssh)"
    prompt_required BRANCH   "Branch to pull"

    git init
    git remote add origin "$REPO_URL"
    git fetch origin "$BRANCH"
    git reset --hard "origin/$BRANCH"
  else
    local current_remote
    current_remote=$(git remote get-url origin 2>/dev/null || echo "")

    if [ -n "${REPO_URL:-}" ] && [ "$current_remote" != "$REPO_URL" ]; then
      warn "Remote mismatch. Updating remote to $REPO_URL"
      git remote set-url origin "$REPO_URL"
    fi

    REPO_URL="${REPO_URL:-$current_remote}"
    BRANCH="${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"

    prompt_required BRANCH "Branch to pull"

    log "Fetching origin/$BRANCH..."
    git fetch origin "$BRANCH"

    log "Force-resetting to origin/$BRANCH (local changes will be overwritten)..."
    git reset --hard "origin/$BRANCH"
    git clean -fd
  fi

  log "Now at: $(git log --oneline -1)"
}

# ── Backend rebuild ───────────────────────────────────────────
rebuild_backend() {
  section "Backend — Rebuild"

  local backend_dir="$SCRIPT_DIR/backend"
  [ -d "$backend_dir" ] || { error "backend/ not found."; exit 1; }

  log "Installing Composer dependencies (no-dev)..."
  composer install --no-dev --optimize-autoloader --no-interaction --working-dir="$backend_dir"

  # Ensure .env exists
  local env_file="$backend_dir/.env"
  if [ ! -f "$env_file" ]; then
    if [ -f "$backend_dir/.env.example" ]; then
      cp "$backend_dir/.env.example" "$env_file"
      warn ".env was missing — copied from .env.example. Review and re-run if needed."
    else
      error "No .env or .env.example found in backend/."
      exit 1
    fi
  fi

  # Generate app key if missing or empty
  local current_key
  current_key=$(grep '^APP_KEY=' "$env_file" | cut -d= -f2)
  if [ -z "$current_key" ]; then
    php "$backend_dir/artisan" key:generate --force
    log "APP_KEY generated."
  fi

  log "Clearing and rebuilding caches..."
  php "$backend_dir/artisan" config:clear
  php "$backend_dir/artisan" route:clear
  php "$backend_dir/artisan" config:cache
  php "$backend_dir/artisan" route:cache

  log "Backend rebuild complete."
}

# ── Frontend rebuild ──────────────────────────────────────────
rebuild_frontend() {
  section "Frontend — Rebuild"

  local frontend_dir="$SCRIPT_DIR/frontend"
  [ -d "$frontend_dir" ] || { error "frontend/ not found."; exit 1; }

  log "Installing npm dependencies..."
  npm ci --prefix "$frontend_dir"

  # Determine API URL for build
  local api_url="${BACKEND_URL:-}"
  if [ -z "$api_url" ]; then
    local env_file="$frontend_dir/.env"
    if [ -f "$env_file" ]; then
      api_url=$(grep '^VITE_API_URL=' "$env_file" | cut -d= -f2)
    fi
  fi

  if [ -z "$api_url" ]; then
    prompt_required api_url "Backend API URL for VITE_API_URL (e.g. https://api.yourdomain.com)"
    BACKEND_URL="$api_url"
  fi

  log "Building frontend (VITE_API_URL=$api_url)..."
  VITE_API_URL="$api_url" npm run build --prefix "$frontend_dir"

  log "Frontend rebuild complete."
}

# ── Azure re-deploy ───────────────────────────────────────────
redeploy_azure() {
  section "Re-deploy to Azure"

  if [ "${SKIP_AZURE:-false}" = "true" ]; then
    warn "SKIP_AZURE=true — skipping Azure deploy."
    return
  fi

  # Need Azure details from .deploy.conf or prompt
  local az_rg="${AZ_RESOURCE_GROUP:-}"
  local az_backend="${AZ_BACKEND_APP:-}"
  local az_frontend="${AZ_FRONTEND_APP:-}"

  if [ -z "$az_rg" ] || [ -z "$az_backend" ] || [ -z "$az_frontend" ]; then
    warn "Azure config not found in .deploy.conf."
    read -rp "Skip Azure re-deploy and build locally only? (y/n): " skip
    if [[ "$skip" =~ ^[Yy]$ ]]; then
      SKIP_AZURE="true"
      warn "Skipped Azure deploy. Run bash deploy.sh to configure and deploy."
      return
    fi
    prompt_required az_rg       "Resource group name"
    prompt_required az_backend  "App Service name (backend)"
    prompt_required az_frontend "Static Web App name (frontend)"
    AZ_RESOURCE_GROUP="$az_rg"
    AZ_BACKEND_APP="$az_backend"
    AZ_FRONTEND_APP="$az_frontend"
  fi

  if ! az account show &>/dev/null; then
    warn "Azure CLI not logged in — run 'az login' then re-run to deploy."
    SKIP_AZURE="true"
    return
  fi

  local timestamp
  timestamp=$(date '+%Y%m%d_%H%M%S')

  # Backend: zip and deploy
  log "Packaging backend..."
  local zip_path="/tmp/filemd-backend-$timestamp.zip"
  (cd "$SCRIPT_DIR/backend" && zip -r "$zip_path" . \
    --exclude "*.git*" \
    --exclude "node_modules/*" \
    --exclude "tests/*" \
    --exclude ".env.backup.*" \
    --exclude "storage/logs/*" \
    --exclude "storage/framework/cache/*" \
    --exclude "storage/framework/sessions/*" \
    --exclude "storage/framework/views/*" \
    > /dev/null)

  log "Deploying backend to App Service: $az_backend"
  az webapp deploy \
    --resource-group "$az_rg" \
    --name "$az_backend" \
    --src-path "$zip_path" \
    --type zip \
    --output none
  rm -f "$zip_path"
  log "Backend deployed."

  # Frontend: deploy dist/
  log "Deploying frontend to Static Web App: $az_frontend"
  local swa_token
  swa_token=$(az staticwebapp secrets list \
    --name "$az_frontend" \
    --resource-group "$az_rg" \
    --query "properties.apiKey" -o tsv)

  npx --yes @azure/static-web-apps-cli deploy \
    "$SCRIPT_DIR/frontend/dist" \
    --deployment-token "$swa_token" \
    --env production

  log "Frontend deployed."
}

# ── Health check ──────────────────────────────────────────────
run_health_check() {
  section "Health Check"

  local backend_url="${BACKEND_URL:-}"
  if [ -z "$backend_url" ]; then
    warn "BACKEND_URL not set — skipping health check."
    return
  fi

  if [ "${SKIP_AZURE:-false}" = "true" ]; then
    # Try local artisan serve for a quick smoke test
    warn "Azure skipped — running local health check via php artisan serve..."
    php "$SCRIPT_DIR/backend/artisan" serve --port=8787 &>/dev/null &
    local pid=$!
    sleep 3
    if curl -sf --max-time 5 "http://localhost:8787/api/health" | grep -q '"ok"'; then
      log "Local health check PASSED."
    else
      warn "Local health check did not respond — check backend manually."
    fi
    kill "$pid" 2>/dev/null || true
    return
  fi

  local url="$backend_url/api/health"
  log "Waiting 10s for services to stabilize..."
  sleep 10

  local retries=6 delay=10 i
  for ((i=1; i<=retries; i++)); do
    log "Attempt $i/$retries — $url"
    if curl -sf --max-time 15 "$url" | grep -q '"ok"'; then
      log "Health check PASSED."
      return 0
    fi
    warn "Not ready yet. Retrying in ${delay}s..."
    sleep "$delay"
  done

  error "Health check FAILED."
  error "Check logs: az webapp log tail --name $AZ_BACKEND_APP --resource-group $AZ_RESOURCE_GROUP"
  return 1
}

# ── Summary ───────────────────────────────────────────────────
print_summary() {
  section "Update Summary"
  echo "  Commit  : $(git -C "$SCRIPT_DIR" log --oneline -1)"
  echo "  Backend : ${BACKEND_URL:-"(local only)"}"
  echo "  Frontend: ${FRONTEND_URL:-"(local only)"}"
  echo ""
  log "Full log: $LOG_FILE"
}

# ── Main ──────────────────────────────────────────────────────
main() {
  echo ""
  echo "========================================"
  echo "  filemd — Update & Redeploy"
  echo "========================================"
  echo "  Log: $LOG_FILE"
  echo "========================================"
  echo ""

  echo "[$(date)] Update started" >> "$LOG_FILE"

  check_prerequisites
  load_config

  echo ""
  read -rp "This will overwrite local changes with the latest from GitHub. Continue? (y/n): " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { warn "Cancelled."; exit 0; }

  pull_latest
  save_config

  rebuild_backend
  rebuild_frontend
  redeploy_azure
  run_health_check
  print_summary

  echo "[$(date)] Update finished" >> "$LOG_FILE"
}

main
