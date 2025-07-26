# Makefile for AWS DevOps Labs Testing Framework

# Variables
PYTHON := python3
PIP := pip3
TEST_DIR := .
VENV_DIR := venv
COVERAGE_DIR := coverage_html
REPORTS_DIR := reports

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help install test test-unit test-integration test-e2e test-all coverage clean lint format security check-deps setup-venv

# Default target
help: ## Show this help message
	@echo "$(BLUE)AWS DevOps Labs Testing Framework$(NC)"
	@echo "=================================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Setup and installation
setup-venv: ## Create and activate virtual environment
	@echo "$(YELLOW)Creating virtual environment...$(NC)"
	$(PYTHON) -m venv $(VENV_DIR)
	@echo "$(GREEN)Virtual environment created. Activate with: source $(VENV_DIR)/bin/activate$(NC)"

install: ## Install test dependencies
	@echo "$(YELLOW)Installing test dependencies...$(NC)"
	$(PIP) install -r requirements.txt
	@echo "$(GREEN)Dependencies installed successfully$(NC)"

install-dev: install ## Install development dependencies
	@echo "$(YELLOW)Installing development dependencies...$(NC)"
	$(PIP) install -e ..
	@echo "$(GREEN)Development dependencies installed$(NC)"

# Testing targets
test: test-all ## Run all tests (alias for test-all)

test-unit: ## Run unit tests only
	@echo "$(YELLOW)Running unit tests...$(NC)"
	$(PYTHON) run_tests.py --suite unit --verbose
	@echo "$(GREEN)Unit tests completed$(NC)"

test-integration: ## Run integration tests only
	@echo "$(YELLOW)Running integration tests...$(NC)"
	$(PYTHON) run_tests.py --suite integration --verbose
	@echo "$(GREEN)Integration tests completed$(NC)"

test-e2e: ## Run end-to-end tests only
	@echo "$(YELLOW)Running end-to-end tests...$(NC)"
	$(PYTHON) run_tests.py --suite e2e --verbose
	@echo "$(GREEN)End-to-end tests completed$(NC)"

test-all: ## Run all test suites
	@echo "$(YELLOW)Running all test suites...$(NC)"
	$(PYTHON) run_tests.py --verbose
	@echo "$(GREEN)All tests completed$(NC)"

test-coverage: ## Run tests with coverage analysis
	@echo "$(YELLOW)Running tests with coverage analysis...$(NC)"
	$(PYTHON) run_tests.py --coverage --verbose
	@echo "$(GREEN)Coverage analysis completed$(NC)"

test-specific: ## Run specific test (usage: make test-specific TEST=test_name)
	@echo "$(YELLOW)Running specific test: $(TEST)$(NC)"
	$(PYTHON) run_tests.py --test $(TEST) --verbose

# Coverage and reporting
coverage: ## Generate detailed coverage report
	@echo "$(YELLOW)Generating coverage report...$(NC)"
	mkdir -p $(COVERAGE_DIR)
	coverage run --source=.. -m pytest
	coverage html -d $(COVERAGE_DIR)
	coverage report
	@echo "$(GREEN)Coverage report generated in $(COVERAGE_DIR)/$(NC)"

coverage-xml: ## Generate XML coverage report for CI
	@echo "$(YELLOW)Generating XML coverage report...$(NC)"
	coverage xml
	@echo "$(GREEN)XML coverage report generated$(NC)"

reports: ## Generate comprehensive test reports
	@echo "$(YELLOW)Generating test reports...$(NC)"
	mkdir -p $(REPORTS_DIR)
	$(PYTHON) run_tests.py --report $(REPORTS_DIR)/test_report.json --coverage
	@echo "$(GREEN)Test reports generated in $(REPORTS_DIR)/$(NC)"

# Code quality
lint: ## Run code linting
	@echo "$(YELLOW)Running code linting...$(NC)"
	flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
	flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
	@echo "$(GREEN)Linting completed$(NC)"

format: ## Format code with black and isort
	@echo "$(YELLOW)Formatting code...$(NC)"
	black .
	isort .
	@echo "$(GREEN)Code formatting completed$(NC)"

format-check: ## Check code formatting without making changes
	@echo "$(YELLOW)Checking code formatting...$(NC)"
	black --check .
	isort --check-only .
	@echo "$(GREEN)Code formatting check completed$(NC)"

# Security
security: ## Run security checks
	@echo "$(YELLOW)Running security checks...$(NC)"
	bandit -r . -f json -o security_report.json || true
	bandit -r . || true
	safety check --json --output safety_report.json || true
	safety check || true
	@echo "$(GREEN)Security checks completed$(NC)"

# Dependency management
check-deps: ## Check for outdated dependencies
	@echo "$(YELLOW)Checking for outdated dependencies...$(NC)"
	$(PIP) list --outdated
	@echo "$(GREEN)Dependency check completed$(NC)"

update-deps: ## Update dependencies to latest versions
	@echo "$(YELLOW)Updating dependencies...$(NC)"
	$(PIP) install --upgrade -r requirements.txt
	@echo "$(GREEN)Dependencies updated$(NC)"

# CloudFormation validation
validate-templates: ## Validate all CloudFormation templates
	@echo "$(YELLOW)Validating CloudFormation templates...$(NC)"
	find .. -name "*.yaml" -path "*/templates/*" -exec cfn-lint {} \;
	@echo "$(GREEN)Template validation completed$(NC)"

# Cleanup
clean: ## Clean up generated files and directories
	@echo "$(YELLOW)Cleaning up...$(NC)"
	rm -rf __pycache__/
	rm -rf .pytest_cache/
	rm -rf .coverage
	rm -rf $(COVERAGE_DIR)/
	rm -rf $(REPORTS_DIR)/
	rm -f *.json
	rm -f *.xml
	find . -name "*.pyc" -delete
	find . -name "*.pyo" -delete
	find . -name "*~" -delete
	@echo "$(GREEN)Cleanup completed$(NC)"

clean-all: clean ## Clean everything including virtual environment
	@echo "$(YELLOW)Cleaning everything...$(NC)"
	rm -rf $(VENV_DIR)/
	@echo "$(GREEN)Complete cleanup finished$(NC)"

# CI/CD targets
ci-setup: ## Setup for CI environment
	@echo "$(YELLOW)Setting up CI environment...$(NC)"
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	@echo "$(GREEN)CI setup completed$(NC)"

ci-test: ## Run tests in CI environment
	@echo "$(YELLOW)Running CI tests...$(NC)"
	$(PYTHON) run_tests.py --coverage --report ci_report.json
	@echo "$(GREEN)CI tests completed$(NC)"

ci-quality: ## Run quality checks for CI
	@echo "$(YELLOW)Running CI quality checks...$(NC)"
	$(MAKE) lint
	$(MAKE) security
	$(MAKE) validate-templates
	@echo "$(GREEN)CI quality checks completed$(NC)"

# Performance testing
perf-test: ## Run performance tests
	@echo "$(YELLOW)Running performance tests...$(NC)"
	@echo "$(RED)Performance testing not yet implemented$(NC)"

# Documentation
docs: ## Generate documentation
	@echo "$(YELLOW)Generating documentation...$(NC)"
	@echo "$(RED)Documentation generation not yet implemented$(NC)"

# Monitoring and debugging
debug: ## Run tests in debug mode
	@echo "$(YELLOW)Running tests in debug mode...$(NC)"
	$(PYTHON) -m pdb run_tests.py --verbose

profile: ## Profile test execution
	@echo "$(YELLOW)Profiling test execution...$(NC)"
	$(PYTHON) -m cProfile -o profile_output.prof run_tests.py
	@echo "$(GREEN)Profiling completed. View with: python -m pstats profile_output.prof$(NC)"

# Quick commands
quick-test: ## Quick test run (unit tests only, no coverage)
	@echo "$(YELLOW)Running quick tests...$(NC)"
	$(PYTHON) run_tests.py --suite unit
	@echo "$(GREEN)Quick tests completed$(NC)"

full-check: ## Run full quality and test suite
	@echo "$(YELLOW)Running full check...$(NC)"
	$(MAKE) format-check
	$(MAKE) lint
	$(MAKE) security
	$(MAKE) validate-templates
	$(MAKE) test-coverage
	@echo "$(GREEN)Full check completed$(NC)"

# Help for specific test patterns
test-help: ## Show help for running specific tests
	@echo "$(BLUE)Test Execution Examples:$(NC)"
	@echo "  make test-unit                    # Run all unit tests"
	@echo "  make test-integration            # Run all integration tests"
	@echo "  make test-e2e                   # Run all end-to-end tests"
	@echo "  make test-specific TEST=test_lab_manager.TestLabManager.test_init"
	@echo "  make test-coverage              # Run tests with coverage"
	@echo ""
	@echo "$(BLUE)Quality Checks:$(NC)"
	@echo "  make lint                       # Check code style"
	@echo "  make format                     # Format code"
	@echo "  make security                   # Security scanning"
	@echo "  make validate-templates         # Validate CloudFormation"
	@echo ""
	@echo "$(BLUE)CI/CD:$(NC)"
	@echo "  make ci-setup                   # Setup CI environment"
	@echo "  make ci-test                    # Run CI test suite"
	@echo "  make full-check                 # Complete quality check"