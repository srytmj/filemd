.PHONY: sync update deploy help

help:
	@echo ""
	@echo "Available commands:"
	@echo "  make sync     Sync stack from docs/SRS.md into .claude/CLAUDE.md"
	@echo "  make update   Pull latest code from GitHub + rebuild + redeploy"
	@echo "  make deploy   Run full deploy wizard (first-time setup on server)"
	@echo ""

sync:
	bash sync.sh

update:
	bash scripts/update.sh

deploy:
	sudo bash scripts/deploy.sh
