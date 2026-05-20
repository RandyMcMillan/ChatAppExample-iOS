SHELL := /bin/sh

SCRIPT_ROOT := scripts
SCRIPT_FILES := $(shell find $(SCRIPT_ROOT) -type f -name '*.sh' | sort)
SCRIPT_TARGETS := $(patsubst $(SCRIPT_ROOT)/%.sh,%,$(SCRIPT_FILES))

.DEFAULT_GOAL := help
.PHONY: help list-scripts $(SCRIPT_TARGETS)

help:
	@printf '%s\n' 'Usage: make <script-target> [ARGS="..."]'
	@printf '\n%s\n' 'Available targets:'
	@for t in $(SCRIPT_TARGETS); do printf '  %-36s ./scripts/%s.sh\n' "$$t" "$$t"; done
	@printf '  %-36s %s\n' help "Show this help"
	@printf '  %-36s %s\n' list-scripts "List script targets"

list-scripts:
	@printf '%s\n' $(SCRIPT_TARGETS)

define RUN_SCRIPT
$1:
	@script="$(SCRIPT_ROOT)/$1.sh"; \
	if [ -x "$$script" ]; then \
		exec "$$script" $(ARGS); \
	else \
		printf 'Unknown target: %s\n' "$1"; \
		$(MAKE) --no-print-directory help; \
		exit 1; \
	fi
endef

$(foreach target,$(SCRIPT_TARGETS),$(eval $(call RUN_SCRIPT,$(target))))