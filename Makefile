# Makefile - HAL v2 (modular, script-driven)
SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables

HAL_ROOT ?= /opt/hal
DOCKER_CMD ?= docker
TAG ?= $(shell date +%Y%m%d-%H%M%S)
export TAG

STACK_DIR ?= $(HAL_ROOT)/stacks

.PHONY: help render-all backup restore system-reset monitoring-status system-diff persona-test

help:
	@echo "HAL v2 Makefile (modular)"
	@echo "Common targets: render-all, backup, restore, system-reset, monitoring-status, system-diff, persona-test"
	@echo "Set DOCKER_CMD='sudo docker' if your environment requires sudo."

render-all:
	@set -euo pipefail; \
	@echo "Rendering templates with TAG=$(TAG) into $(STACK_DIR)"; \
	./scripts/render-templates.sh

backup:
	@set -euo pipefail; \
	@echo "Running backup script"; \
	./scripts/backup.sh --out "$(HAL_ROOT)/backups" --tag "$(TAG)"

restore:
	@set -euo pipefail; \
	@echo "Restore requires --file and --yes. Example:"; \
	@echo "  make restore FILE=/path/to/backup.tar.gz"; \
	@echo "To actually run: ./scripts/restore.sh --file /path/to/backup.tar.gz --yes"

system-reset:
	@set -euo pipefail; \
	@echo "Destructive: requires RESET_CONFIRM=yes or --yes"; \
	@if [ "$${RESET_CONFIRM:-no}" != "yes" ]; then \
	echo "✖ To proceed export RESET_CONFIRM=yes or run ./scripts/system-reset.sh --yes"; \
	exit 2; \
	fi; \
	./scripts/system-reset.sh --yes

monitoring-status:
	@set -euo pipefail; \
	echo "→ Checking Prometheus and Grafana health"; \
	curl --fail --silent --show-error --max-time 5 http://prometheus:9090/-/healthy || echo "  ✖ Prometheus unreachable"; \
	curl --fail --silent --show-error --max-time 5 http://grafana:3000/api/health || echo "  ✖ Grafana unreachable"; \
	echo "✔ Monitoring status check complete"

system-diff:
	@set -euo pipefail; \
	echo "→ Checking image digests for router, node1, node2, tools"; \
	$(DOCKER_CMD) image inspect --format='{{index .RepoDigests 0}}' hal-router:$(TAG) 2>/dev/null || echo "  ✖ hal-router:$(TAG) not found"; \
	$(DOCKER_CMD) image inspect --format='{{index .RepoDigests 0}}' hal-node1:$(TAG) 2>/dev/null || echo "  ✖ hal-node1:$(TAG) not found"; \
	$(DOCKER_CMD) image inspect --format='{{index .RepoDigests 0}}' hal-node2:$(TAG) 2>/dev/null || echo "  ✖ hal-node2:$(TAG) not found"; \
	$(DOCKER_CMD) image inspect --format='{{index .RepoDigests 0}}' hal-tools:$(TAG) 2>/dev/null || echo "  ✖ hal-tools:$(TAG) not found"; \
	echo "✔ Digest comparison complete"

persona-test:
	@set -euo pipefail; \
	echo "→ Running persona / routing smoke tests"; \
	curl --fail --silent --show-error --max-time 5 -X POST http://localhost:9001/completion -H "Content-Type: application/json" -d '{"prompt":"HAL persona test from Makefile"}' || echo "  ✖ Router completion failed"; \
	curl --fail --silent --show-error --max-time 5 http://ai-srv-node1:9001/health || echo "  ✖ Node1 health failed"; \
	curl --fail --silent --show-error --max-time 5 http://ai-srv-node2:9001/health || echo "  ✖ Node2 health failed"; \
	curl --fail --silent --show-error --max-time 5 http://localhost:9100/health || echo "  ✖ Memory health failed"; \
	echo "✔ Persona / routing tests complete"
