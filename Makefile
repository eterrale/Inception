# =============================================================================
# Transcendance - Makefile
# =============================================================================

PROJECT_NAME := transcendance
COMPOSE_FILE := srcs/docker-compose.yaml
COMPOSE      := docker compose -p $(PROJECT_NAME) -f $(COMPOSE_FILE)
LOG_DIR      := logs

ENV_FILE     := srcs/.env
SECRETS_DIR  := secrets
SECRETS := mariadb/db_root_password.txt mariadb/db_password.txt credentials.txt wp_user_password.txt

RED    := \033[0;31m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
NC     := \033[0m

.PHONY: all build up down front back \
        logs ps \
        clean fclean \
        check-env check-secrets \
        help

# -----------------------------------------------------------------------------
# Default target
# -----------------------------------------------------------------------------
all: help

# -----------------------------------------------------------------------------
# Safety checks
# -----------------------------------------------------------------------------
check-env: ## Verify srcs/.env exists and required variables are set
	@if [ ! -f "$(ENV_FILE)" ]; then \
		printf "$(RED)Error:$(NC) $(ENV_FILE) not found.\n"; \
		printf "$(YELLOW)Fix:$(NC) create $(ENV_FILE) before running make (see README).\n"; \
		exit 1; \
	fi
	@for var in DOMAIN_NAME MYSQL_USER MYSQL_DATABASE; do \
		value=$$(grep -E "^$$var=" $(ENV_FILE) | cut -d '=' -f2-); \
		if [ -z "$$value" ]; then \
			printf "$(RED)Error:$(NC) $$var is missing or empty in $(ENV_FILE)\n"; \
			printf "$(YELLOW)Fix:$(NC) add a value for $$var in $(ENV_FILE)\n"; \
			exit 1; \
		fi; \
	done

check-secrets: ## Verify secret files exist and are not empty
	@for f in $(SECRETS); do \
		if [ ! -f "$(SECRETS_DIR)/$$f" ]; then \
			printf "$(RED)Error:$(NC) missing $(SECRETS_DIR)/$$f - see README for secrets setup\n"; \
			exit 1; \
		fi; \
		if [ ! -s "$(SECRETS_DIR)/$$f" ]; then \
			printf "$(RED)Error:$(NC) $(SECRETS_DIR)/$$f is empty - fill it in before running make\n"; \
			exit 1; \
		fi; \
	done

# -----------------------------------------------------------------------------
# Build & run
# -----------------------------------------------------------------------------
build: check-env check-secrets ## Build and start all services (front + back + postgres)
	$(COMPOSE) up --build -d

up: check-env check-secrets ## Start all services (front + back + postgres)
	$(COMPOSE) up -d

down: ## Stop and remove all containers
	$(COMPOSE) down

front: check-env check-secrets ## Build and start only the front service
	$(COMPOSE) up --build -d front

back: check-env check-secrets ## Build and start only the back service (+ postgres if needed)
	$(COMPOSE) up --build -d back

# -----------------------------------------------------------------------------
# Rebuild
# -----------------------------------------------------------------------------
re: down up ## Full rebuild of the whole stack (down + up, keeps volumes)

# -----------------------------------------------------------------------------
# Logs
# -----------------------------------------------------------------------------
logs: ## Tail logs for all services
	$(COMPOSE) logs -f

# -----------------------------------------------------------------------------
# Status
# -----------------------------------------------------------------------------
ps: ## Show status of running containers
	$(COMPOSE) ps

# -----------------------------------------------------------------------------
# Cleaning
# -----------------------------------------------------------------------------
clean: ## Stop containers and remove associated images/networks (keeps volumes)
	$(COMPOSE) down --rmi all

fclean: ## Full clean: also remove named volumes (asks for confirmation, scoped to this project only)
	@printf "$(YELLOW)WARNING:$(NC) this will remove all containers, images AND named volumes (e.g. postgres data) for this project only.\n"
	@read -p "Are you sure? [y/N] " confirm && \
		if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
			$(COMPOSE) down -v --rmi all && \
			docker image prune -f --filter "label=com.docker.compose.project=$(PROJECT_NAME)" && \
			docker volume prune -f --filter "label=com.docker.compose.project=$(PROJECT_NAME)" && \
			docker network prune -f --filter "label=com.docker.compose.project=$(PROJECT_NAME)"; \
		else \
			printf "$(CYAN)Aborted.$(NC)\n"; \
		fi

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help: ## Show this help message
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""