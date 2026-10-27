# Makefile — the one interface learners need.  Run `make` or `make help`.
#
# How Make works (enough for this lab):
#
#   target: prerequisites      ## description shown by `make help`
#   <TAB>command
#   <TAB>another command
#
#   - Recipe lines MUST start with a Tab character, not spaces.
#   - Each line runs in its own shell. Join with && if one depends on the last.
#   - Prefix a line with @ to hide the command and only show its output.
#   - .PHONY lists targets that are commands, not files Make should build.
#   - Prerequisites run first: `up: env` makes sure .env exists before starting.

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Read .env (if present) so its values are available here as $(HELLO_PORT) etc.
-include .env
export

COMPOSE := docker compose

.PHONY: help env doctor up down ps logs reset check-m00

help: ## Show this list
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

env: ## Create .env from .env.example if it doesn't exist yet
	@if [ ! -f .env ]; then cp .env.example .env && echo "Created .env — edit it before continuing."; fi

# ---------------------------------------------------------------------------
# TODO — replace each `todo` line below with the real command(s).
#   Keep the Tab at the start of each line!
# ---------------------------------------------------------------------------

doctor: ## Check this Mac is ready for the lab
	@echo "TODO: run scripts/doctor.sh" && exit 1

up: env ## Start the lab services in the background
	@echo "TODO: start the services with \$$(COMPOSE), detached, and WAIT until they are healthy" && exit 1
	@# Hint: docker compose up has a --wait flag. Then print the hello URL using $(HELLO_PORT).

down: ## Stop the lab (keeps data in volumes)
	@echo "TODO: stop and remove the containers, but keep the volumes" && exit 1

ps: ## Show running services and their health
	@echo "TODO: list the services" && exit 1

logs: ## Follow service logs (Ctrl-C to stop)
	@echo "TODO: follow the logs of all services" && exit 1

reset: ## Stop the lab AND delete all its data (asks first)
	@echo "TODO: ask for confirmation, then stop everything and delete the volumes" && exit 1
	@# Hint: read -p "Delete all lab data? [y/N] " ans && [ "$$ans" = y ]
	@# Make turns $$ into a single $ before the shell sees it. Why is that needed?
	@# Bonus: skip the question when run as `make reset FORCE=1` (the checker uses this).

check-m00: ## Check your Milestone 0 work
	@bash scripts/check_m00.sh
