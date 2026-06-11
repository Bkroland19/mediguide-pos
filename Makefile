BACKEND_DIR := backend
AI_WORKER_DIR := ai-worker
COMPOSE_FILE := infra/docker-compose.yml
DOCKER_COMPOSE := docker compose -f $(COMPOSE_FILE)
PYTHON ?= python3
AI_REQUIREMENTS_FILE := $(AI_WORKER_DIR)/requirements.txt
AI_REQUIREMENTS_STAMP := $(AI_WORKER_DIR)/.requirements.sha256

.DEFAULT_GOAL := help

.PHONY: help
help:
	@printf "%s\n" \
		"Available targets:" \
		"  up               Start the shared local stack from infra/docker-compose.yml" \
		"  down             Stop the shared local stack" \
		"  build            Build the shared local stack" \
		"  ps               Show shared local stack status" \
		"  logs             Tail shared local stack logs" \
		"  config           Render shared local compose config" \
		"  test             Run backend and ai-worker tests" \
		"  backend-test     Run backend Go tests" \
		"  backend-build    Build backend binaries" \
		"  backend-run      Run backend API locally" \
		"  backend-worker   Run backend Go worker locally" \
		"  swagger          Generate backend Swagger JSON/YAML docs" \
		"  migrate-up       Apply backend migrations" \
		"  migrate-down     Roll back backend migrations" \
		"  migrate-status   Show backend migration status" \
		"  seed             Seed backend data" \
		"  importpb         Import PocketBase SQLite data into backend Postgres" \
		"  ai-test          Run ai-worker tests" \
		"  ai-api           Run ai-worker FastAPI locally" \
		"  ai-worker        Run ai-worker loop locally"

.PHONY: up
up:
	$(DOCKER_COMPOSE) up -d --build

.PHONY: down
down:
	$(DOCKER_COMPOSE) down -v --remove-orphans

.PHONY: build
build:
	$(DOCKER_COMPOSE) build

.PHONY: ps
ps:
	$(DOCKER_COMPOSE) ps

.PHONY: logs
logs:
	$(DOCKER_COMPOSE) logs -f

.PHONY: config
config:
	$(DOCKER_COMPOSE) config

.PHONY: test
test: backend-test ai-test

.PHONY: backend-test
backend-test:
	$(MAKE) -C $(BACKEND_DIR) test

.PHONY: backend-build
backend-build:
	$(MAKE) -C $(BACKEND_DIR) build

.PHONY: backend-run
backend-run:
	$(MAKE) -C $(BACKEND_DIR) run

.PHONY: backend-worker
backend-worker:
	$(MAKE) -C $(BACKEND_DIR) worker

.PHONY: swagger
swagger:
	$(MAKE) -C $(BACKEND_DIR) swagger

.PHONY: migrate-up
migrate-up:
	$(MAKE) -C $(BACKEND_DIR) migrate-up

.PHONY: migrate-down
migrate-down:
	$(MAKE) -C $(BACKEND_DIR) migrate-down

.PHONY: migrate-status
migrate-status:
	$(MAKE) -C $(BACKEND_DIR) migrate-status

.PHONY: seed
seed:
	$(MAKE) -C $(BACKEND_DIR) seed

.PHONY: importpb
importpb:
	$(MAKE) -C $(BACKEND_DIR) importpb

.PHONY: ai-test
ai-test: ai-deps
	cd $(AI_WORKER_DIR) && $(PYTHON) -m pytest

.PHONY: ai-deps
ai-deps:
	@REQ_HASH=`$(PYTHON) - <<'PY'\nimport hashlib\nfrom pathlib import Path\nprint(hashlib.sha256(Path('$(AI_REQUIREMENTS_FILE)').read_bytes()).hexdigest())\nPY`; \
	STORED_HASH=""; \
	if [ -f "$(AI_REQUIREMENTS_STAMP)" ]; then STORED_HASH=`cat "$(AI_REQUIREMENTS_STAMP)"`; fi; \
	if [ "$$REQ_HASH" != "$$STORED_HASH" ]; then \
		echo "Installing ai-worker requirements"; \
		cd $(AI_WORKER_DIR) && $(PYTHON) -m pip install -r requirements.txt; \
		printf "%s" "$$REQ_HASH" > "$(AI_REQUIREMENTS_STAMP)"; \
	else \
		echo "ai-worker requirements unchanged"; \
	fi

.PHONY: ai-api
ai-api: ai-deps
	cd $(AI_WORKER_DIR) && uvicorn app.main:app --reload --host 0.0.0.0 --port 8090

.PHONY: ai-worker
ai-worker: ai-deps
	cd $(AI_WORKER_DIR) && $(PYTHON) -m app.worker

.PHONY: run-cfdp-ios-simulator
run-cfdp-ios-simulator:
	cd user_app && \
	flutter run --dart-define=MEDIGUIDE_API_BASE_URL=https://mediguide.health.go.ug
