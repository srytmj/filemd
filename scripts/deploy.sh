#!/bin/bash

# =============================================================
# deploy.sh - Deploy wizard for filemd (Azure App Service + Azure Static Web Apps)
# Usage: bash deploy.sh
#
# Requirements:
#   - Azure CLI (az) logged in
#   - Node.js + npm
#   - PHP + Composer
#   - @azure/static-web-apps-cli: npm i -g @azure/static-web-apps-cli
# =============================================================

set -euo pipefail

CONFIG_FILE=".deploy.conf"
LOG_FILE="deploy.log"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
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

prompt_secret() {
  local var_name="$1" prompt_text="$2" input
  while true; do
    read -rsp "$prompt_text: " input; echo ""
    [ -n "$input" ] && { eval "$var_name=\"$input\""; break; } || warn "Cannot be empty."
  done
}

# ── Config ────────────────────────────────────────────────────
load_config() {
  [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE" && log "Config loaded from $CONFIG_FILE"
}

save_config() {
  cat > "$CONFIG_FILE" <<EOF
AZ_SUBSCRIPTION="${AZ_SUBSCRIPTION:-}"
AZ_RESOURCE_GROUP="${AZ_RESOURCE_GROUP:-}"
AZ_BACKEND_APP="${AZ_BACKEND_APP:-}"
AZ_FRONTEND_APP="${AZ_FRONTEND_APP:-}"
BACKEND_URL="${BACKEND_URL:-}"
FRONTEND_URL="${FRONTEND_URL:-}"
EOF
  log "Config saved to $CONFIG_FILE"
}

# ── Prereq checks ─────────────────────────────────────────────
check_prerequisites() {
  section "Checking Prerequisites"

  local missing=0

  for cmd in az php composer node npm; do
    if command -v "$cmd" &>/dev/null; then
      log "$cmd: $(command -v "$cmd")"
    else
      error "$cmd not found — please install it first."
      missing=1
    fi
  done

  if ! az account show &>/dev/null; then
    error "Azure CLI not logged in. Run: az login"
    missing=1
  else
    log "Azure CLI: logged in as $(az account show --query user.name -o tsv)"
  fi

  [ "$missing" -eq 1 ] && { error "Fix prerequisites above and re-run."; exit 1; }
}

# ── Azure config ──────────────────────────────────────────────
setup_azure() {
  section "Azure Configuration"

  prompt_required AZ_SUBSCRIPTION    "Azure subscription ID or name"
  az account set --subscription "$AZ_SUBSCRIPTION"
  log "Subscription set: $AZ_SUBSCRIPTION"

  prompt_required AZ_RESOURCE_GROUP  "Resource group name"
  prompt_required AZ_BACKEND_APP     "App Service name (backend)"
  prompt_required AZ_FRONTEND_APP    "Static Web App name (frontend)"
  prompt_required BACKEND_URL        "Backend URL (e.g. https://api.yourdomain.com)"
  prompt_required FRONTEND_URL       "Frontend URL (e.g. https://yourdomain.com)"
}

# ── Backend deploy ────────────────────────────────────────────
deploy_backend() {
  section "Backend — Build & Deploy"

  local backend_dir="$SCRIPT_DIR/backend"
  [ -d "$backend_dir" ] || { error "backend/ directory not found at $SCRIPT_DIR"; exit 1; }

  log "Installing Composer dependencies (no-dev)..."
  composer install --no-dev --optimize-autoloader --no-interaction --working-dir="$backend_dir"

  # Backup then write production .env
  local env_file="$backend_dir/.env"
  [ -f "$env_file" ] && cp "$env_file" "$env_file.backup.$TIMESTAMP" && log "Backed up backend .env"

  if [ ! -f "$env_file" ]; then
    cp "$backend_dir/.env.example" "$env_file"
  fi

  write_env_key "$env_file" "APP_ENV"      "production"
  write_env_key "$env_file" "APP_DEBUG"    "false"
  write_env_key "$env_file" "APP_URL"      "$BACKEND_URL"
  write_env_key "$env_file" "FRONTEND_URL" "$FRONTEND_URL"

  # Generate app key if missing
  local current_key
  current_key=$(grep '^APP_KEY=' "$env_file" | cut -d= -f2)
  if [ -z "$current_key" ] || [ "$current_key" = "" ]; then
    php "$backend_dir/artisan" key:generate --force
    log "APP_KEY generated."
  fi

  log "Caching config and routes..."
  php "$backend_dir/artisan" config:cache
  php "$backend_dir/artisan" route:cache

  log "Creating deployment zip..."
  local zip_path="/tmp/filemd-backend-$TIMESTAMP.zip"
  (cd "$backend_dir" && zip -r "$zip_path" . \
    --exclude "*.git*" \
    --exclude "node_modules/*" \
    --exclude "tests/*" \
    --exclude ".env.backup.*" \
    --exclude "storage/logs/*" \
    --exclude "storage/framework/cache/*" \
    --exclude "storage/framework/sessions/*" \
    --exclude "storage/framework/views/*" \
    > /dev/null)

  log "Deploying backend to App Service: $AZ_BACKEND_APP"
  az webapp deploy \
    --resource-group "$AZ_RESOURCE_GROUP" \
    --name "$AZ_BACKEND_APP" \
    --src-path "$zip_path" \
    --type zip \
    --output none

  rm -f "$zip_path"
  log "Backend deployed."

  # Set required App Service env vars via az webapp config appsettings
  log "Setting App Service application settings..."
  az webapp config appsettings set \
    --resource-group "$AZ_RESOURCE_GROUP" \
    --name "$AZ_BACKEND_APP" \
    --settings \
      APP_ENV=production \
      APP_DEBUG=false \
      APP_URL="$BACKEND_URL" \
      FRONTEND_URL="$FRONTEND_URL" \
    --output none
  log "App Service settings updated."
}

# ── Frontend deploy ───────────────────────────────────────────
deploy_frontend() {
  section "Frontend — Build & Deploy"

  local frontend_dir="$SCRIPT_DIR/frontend"
  [ -d "$frontend_dir" ] || { error "frontend/ directory not found at $SCRIPT_DIR"; exit 1; }

  log "Installing npm dependencies..."
  npm ci --prefix "$frontend_dir"

  log "Building frontend (VITE_API_URL=$BACKEND_URL)..."
  VITE_API_URL="$BACKEND_URL" npm run build --prefix "$frontend_dir"

  log "Deploying to Azure Static Web Apps: $AZ_FRONTEND_APP"

  # Retrieve deployment token
  local swa_token
  swa_token=$(az staticwebapp secrets list \
    --name "$AZ_FRONTEND_APP" \
    --resource-group "$AZ_RESOURCE_GROUP" \
    --query "properties.apiKey" -o tsv)

  npx --yes @azure/static-web-apps-cli deploy \
    "$frontend_dir/dist" \
    --deployment-token "$swa_token" \
    --env production

  log "Frontend deployed."
}

# ── Health check ──────────────────────────────────────────────
run_health_check() {
  section "Health Check"

  local url="$BACKEND_URL/api/health"
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

  error "Health check FAILED after $retries attempts."
  error "Check App Service logs: az webapp log tail --name $AZ_BACKEND_APP --resource-group $AZ_RESOURCE_GROUP"
  return 1
}

# ── Summary ───────────────────────────────────────────────────
print_summary() {
  section "Deploy Summary"
  echo "  Backend     : $BACKEND_URL"
  echo "  Frontend    : $FRONTEND_URL"
  echo "  App Service : $AZ_BACKEND_APP  (resource group: $AZ_RESOURCE_GROUP)"
  echo "  Static App  : $AZ_FRONTEND_APP (resource group: $AZ_RESOURCE_GROUP)"
  echo ""
  log "Full log: $LOG_FILE"
}

# ── Helpers ───────────────────────────────────────────────────
write_env_key() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

# ── Main ──────────────────────────────────────────────────────
main() {
  echo ""
  echo "========================================"
  echo "  filemd — Deploy Wizard"
  echo "  Laravel API  →  Azure App Service"
  echo "  React/Vite   →  Azure Static Web Apps"
  echo "========================================"
  echo "  Log: $LOG_FILE"
  echo "========================================"
  echo ""

  echo "[$(date)] Deploy started" >> "$LOG_FILE"

  check_prerequisites
  load_config
  setup_azure
  save_config

  deploy_backend
  deploy_frontend
  run_health_check
  print_summary

  echo "[$(date)] Deploy finished" >> "$LOG_FILE"
}

main
