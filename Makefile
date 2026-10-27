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
# Must match the spark service's image: in docker-compose.yml.
SPARK_IMAGE := lakehouse/spark:4.1.3-iceberg1.12.0

.PHONY: help env doctor docker-config up urls data build shell down ps logs reset check-m00

help: ## Show this list
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

env: ## Create .env from .env.example if it doesn't exist yet
	@if [ ! -f .env ]; then cp .env.example .env && echo "Created .env from .env.example (the defaults work; change a port only if make doctor says it's taken)."; fi

# ---------------------------------------------------------------------------
# Lab commands. $(COMPOSE) = docker compose (set above).
# ---------------------------------------------------------------------------

doctor: env ## Check this Mac is ready for the lab
	@bash scripts/doctor.sh

# -d = run in the background; --wait = return only once the healthcheck says healthy.
up: env ## Start the lab services in the background
	@if ! docker image inspect $(SPARK_IMAGE) >/dev/null 2>&1; then \
	  echo "First run: building the Spark image ($(SPARK_IMAGE)). This takes 2-5 minutes, once."; \
	fi
	$(COMPOSE) up -d --wait
	@$(MAKE) -s urls

urls: ## Show the URL of every lab service
	@echo ""
	@echo "  Jupyter (notebooks)  http://localhost:$(JUPYTER_PORT)"
	@echo "  Spark UI             http://localhost:$(SPARK_UI_PORT)   (only while a Spark session is running)"
	@echo "  RustFS console (S3)  http://localhost:$(S3_CONSOLE_PORT)/rustfs/console/   login: $(S3_ACCESS_KEY) / $(S3_SECRET_KEY)"
	@echo "  Iceberg REST catalog http://localhost:$(CATALOG_PORT)/v1/config"
	@echo "  Hello app (M0)       http://localhost:$(HELLO_PORT)"

docker-config: ## Let Docker find the Compose/buildx plugins from Homebrew (setup, once)
	@bash scripts/docker_config.sh

data: ## Download the NYC Taxi sample data (~100 MB, checksum-verified)
	@bash scripts/download_data.sh

build: ## Rebuild the Spark image (after changing docker/spark/)
	$(COMPOSE) build spark

shell: ## Open an interactive PySpark shell inside the Spark container
	$(COMPOSE) exec spark pyspark

# No -v: containers are removed, volumes (your data) are kept.
down: ## Stop the lab (keeps data in volumes)
	$(COMPOSE) down

ps: ## Show running services and their health
	$(COMPOSE) ps

# -f = keep following new log lines until Ctrl-C.
logs: ## Follow service logs (Ctrl-C to stop)
	$(COMPOSE) logs -f

# Asks first unless run as `make reset FORCE=1`. down -v also deletes the volumes.
# $$ans: Make turns $$ into $ before the shell runs the line.
reset: ## Stop the lab AND delete all its data (asks first)
	@if [ "$(FORCE)" != "1" ]; then \
	  read -p "Delete all lab data? [y/N] " ans && [ "$$ans" = "y" ] || { echo "Cancelled."; exit 1; }; \
	fi
	$(COMPOSE) down -v

check-m00: ## Check your Milestone 0 work
	@bash scripts/check_m00.sh
