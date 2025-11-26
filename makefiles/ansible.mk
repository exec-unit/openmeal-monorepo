# ============================================================================
# Ansible Testing (Molecule)
# ============================================================================

.PHONY: test test-ansible test-ansible-role test-ansible-lint test-ansible-syntax

## test-ansible: Run all Ansible role tests with Molecule
test-ansible:
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)║              Ansible Molecule Tests                            ║$(RESET)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@cd infrastructure/ansible && \
	set -e; \
	for role in roles/*/; do \
		role_name=$$(basename $$role); \
		if [ -d "$$role/molecule/default" ]; then \
			echo "$(CYAN)→ Testing role: $$role_name$(RESET)"; \
			(cd $$role && molecule test && cd ../..) || { \
				echo "$(RED)✗ Role $$role_name tests failed$(RESET)"; \
				exit 1; \
			}; \
		fi; \
	done
	@echo ""
	@echo "$(GREEN)✓ All Ansible tests passed$(RESET)"

## test-ansible-role: Test single Ansible role (usage: make test-ansible-role ROLE=common)
test-ansible-role:
	@if [ -z "$(ROLE)" ]; then \
		echo "$(RED)✗ Error: ROLE not specified$(RESET)"; \
		echo "$(YELLOW)Usage: make test-ansible-role ROLE=common$(RESET)"; \
		exit 1; \
	fi
	@echo "$(CYAN)→ Testing Ansible role: $(ROLE)$(RESET)"
	@cd infrastructure/ansible/roles/$(ROLE) && molecule test
	@echo "$(GREEN)✓ Role $(ROLE) tests passed$(RESET)"

## test-ansible-lint: Run ansible-lint on all roles
test-ansible-lint:
	@echo "$(CYAN)→ Running ansible-lint...$(RESET)"
	@cd infrastructure/ansible && ansible-lint roles/
	@echo "$(GREEN)✓ Linting passed$(RESET)"

## test-ansible-syntax: Check Ansible playbook syntax
test-ansible-syntax:
	@echo "$(CYAN)→ Checking Ansible syntax...$(RESET)"
	@cd infrastructure/ansible && \
	for playbook in playbooks/*.yml; do \
		echo "  Checking $$playbook..."; \
		ansible-playbook --syntax-check $$playbook; \
	done
	@echo "$(GREEN)✓ Syntax check passed$(RESET)"

## test: Run all tests (Ansible + future tests)
test: test-ansible-lint test-ansible-syntax test-ansible
	@echo "$(GREEN)✓ All tests passed$(RESET)"
