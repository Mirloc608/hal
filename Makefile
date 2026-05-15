#!/usr/bin/env make
# Makefile - HAL v2 (upgraded, modular)
SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables

HAL_ROOT ?= /opt/hal
DOCKER_CMD ?= docker
TAG ?= $(shell date +%Y%m%d-%H%M%S)
export TAG

STACK_DIR ?= $(HAL_ROOT)/stacks
SERVICES_DIR ?= $(HAL_ROOT)/services
LOCKFILE ?= $(HAL_ROOT)/Makefile.lock

.PHONY: help render-all backup restore system-reset monitoring-status system-diff persona-test ci-checks \
		build-all build-all-parallel build-parallel deploy-all system-up generate-lockfile pin-stacks stack-lint \
		cluster-doctor

help:
	@echo "HAL v2 Makefile (modular)"
	@echo "Common targets: render-all, backup, restore, system-reset, monitoring-status, system-diff, persona-test"
	@echo "New targets: build-all, build-all-parallel, deploy-all, generate-lockfile, pin-stacks, stack-lint, cluster-doctor, system-up"
	@echo "Set DOCKER_CMD='sudo docker' if your environment requires sudo."

# -------------------------
# Existing targets (kept)
# -------------------------
render-all:
	@set -euo pipefail; \
	echo "Rendering templates with TAG=$(TAG) into $(STACK_DIR)"; \
	./scripts/render-templates.sh

backup:
	@set -euo pipefail; \
	echo "Running backup script"; \
	./scripts/backup.sh --out "$(HAL_ROOT)/backups" --tag "$(TAG)"

restore:
	@set -euo pipefail; \
	echo "Restore requires --file and --yes. Example:"; \
	echo "  make restore FILE=/path/to/backup.tar.gz"; \
	echo "To actually run: ./scripts/restore.sh --file /path/to/backup.tar.gz --yes"

system-reset:
	@set -euo pipefail; \
	echo "Destructive: requires RESET_CONFIRM=yes or --yes"; \
	if [ "$${RESET_CONFIRM:-no}" != "yes" ]; then \
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

ci-checks:
	@echo "Running local CI checks (shellcheck, shfmt, bats)"; \
	./scripts/ci/checks.sh

# -------------------------
# Build targets
# -------------------------
SERVICES := router node1 node2 ke planner tools hal

build-all:
	@set -euo pipefail; \
	echo "→ Building all HAL service images with TAG=$(TAG)"; \
	for svc in $(SERVICES); do \
		echo "  → Building $$svc"; \
		$(DOCKER_CMD) build -t hal-$$svc:$(TAG) $(SERVICES_DIR)/$$svc; \
	done; \
	echo "✔ build-all complete"

# Parallel build using xargs -P 8; falls back to sequential if xargs -P not available
build-all-parallel:
	@set -euo pipefail; \
	echo "→ Building all HAL service images in parallel (8 workers) with TAG=$(TAG)"; \
	printf "%s\n" $(SERVICES) | xargs -n1 -P8 -I{} sh -c 'echo "  → Building {}"; $(DOCKER_CMD) build -t hal-{}:$(TAG) $(SERVICES_DIR)/{}' || (echo "Parallel build failed, falling back to sequential"; $(MAKE) build-all); \
	echo "✔ build-all-parallel complete"

build-parallel:
	@$(MAKE) build-all-parallel

# -------------------------
# Lockfile and pinning
# -------------------------
generate-lockfile:
	@set -euo pipefail; \
	echo "→ Generating lockfile at $(LOCKFILE)"; \
	echo "# Makefile.lock generated: $$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > $(LOCKFILE); \
	for svc in $(SERVICES); do \
		img="hal-$$svc:$(TAG)"; \
		digest=$$($(DOCKER_CMD) image inspect --format='{{index .RepoDigests 0}}' $$img 2>/dev/null || true); \
		if [ -z "$$digest" ]; then \
			echo "  ✖ $$img not found locally; skipping"; \
			echo "$$svc=" >> $(LOCKFILE); \
		else \
			echo "$$svc=$$digest" >> $(LOCKFILE); \
			echo "  → $$svc pinned to $$digest"; \
		fi; \
	done; \
	echo "✔ generate-lockfile complete"

pin-stacks:
	@set -euo pipefail; \
	if [ ! -f $(LOCKFILE) ]; then echo "Lockfile not found. Run make generate-lockfile first"; exit 2; fi; \
	echo "→ Pinning stacks using $(LOCKFILE)"; \
	while IFS='=' read -r svc digest; do \
		if [ -z "$$svc" ] || echo "$$svc" | grep -q '^#'; then continue; fi; \
		if [ -z "$$digest" ]; then echo "  ✖ $$svc has no digest in lockfile"; continue; fi; \
		sed -i.bak -E "s|hal-$$svc:$(TAG)|$$digest|g" $(STACK_DIR)/*.yml || true; \
		echo "  → pinned hal-$$svc to $$digest in stacks"; \
	done < <(grep -v '^#' $(LOCKFILE) | sed '/^$$/d'); \
	echo "✔ pin-stacks complete"

# -------------------------
# Linting and validation
# -------------------------
stack-lint:
	@set -euo pipefail; \
	echo "→ Running stack linter"; \
	./scripts/stack-linter.sh $(STACK_DIR) || (echo "  ✖ stack-lint found issues"; exit 2); \
	echo "✔ stack-lint complete"

# -------------------------
# Deploy targets
# -------------------------
deploy-all:
	@set -euo pipefail; \
	echo "→ Deploying all HAL stacks"; \
	$(DOCKER_CMD) stack deploy -c $(STACK_DIR)/router.yml  router  --with-registry-auth; \
	$(DOCKER_CMD) stack deploy -c $(STACK_DIR)/node1.yml	node1	--with-registry-auth; \
	$(DOCKER_CMD) stack deploy -c $(STACK_DIR)/node2.yml	node2	--with-registry-auth; \
	$(DOCKER_CMD) stack deploy -c $(STACK_DIR)/ke.yml	  ke	  --with-registry-auth; \
	$(DOCKER_CMD) stack deploy -c $(STACK_DIR)/planner.yml planner --with-registry-auth; \
	$(DOCKER_CMD) stack deploy -c $(STACK_DIR)/tools.yml	tools	--with-registry-auth; \
	$(DOCKER_CMD) stack deploy -c $(STACK_DIR)/hal.yml	 hal	 --with-registry-auth; \
	echo "✔ deploy-all complete"

# -------------------------
# Cluster doctor
# -------------------------
cluster-doctor:
	@set -euo pipefail; \
	echo "→ Running cluster doctor checks"; \
	./scripts/cluster-doctor.sh || (echo "  ✖ cluster-doctor found issues"; exit 2); \
	echo "✔ cluster-doctor complete"

# -------------------------
# Full system-up (uses new targets)
# -------------------------
system-up:
	@echo "⚠ FULL SYSTEM REBUILD — reset + build + render + pin + deploy"
	@echo "→ Step 1: system-reset"
	$(MAKE) system-reset RESET_CONFIRM=yes
	@echo "→ Step 2: build-all-parallel"
	$(MAKE) build-all-parallel
	@echo "→ Step 3: render-all"
	$(MAKE) render-all
	@echo "→ Step 4: generate-lockfile"
	$(MAKE) generate-lockfile
	@echo "→ Step 5: pin-stacks"
	$(MAKE) pin-stacks
	@echo "→ Step 6: stack-lint"
	$(MAKE) stack-lint
	@echo "→ Step 7: cluster-doctor"
	$(MAKE) cluster-doctor
	@echo "→ Step 8: deploy-all"
	$(MAKE) deploy-all
	@echo "✔ system-up complete"
