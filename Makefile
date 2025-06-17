# OCM Demo Makefile
# Simple commands for the OCM Demo Playground

.PHONY: help setup demo clean test validate lint check examples

# Default target
help:
	@echo "OCM Demo Playground - Available commands:"
	@echo ""
	@echo "🚀 Getting Started:"
	@echo "  setup     - Set up the demo environment"
	@echo "  demo      - Run the quick demo"
	@echo ""
	@echo "🧪 Testing & Validation:"
	@echo "  test      - Run all tests"
	@echo "  validate  - Validate scripts and documentation"
	@echo "  lint      - Run shellcheck on all scripts"
	@echo "  check     - Run all validation checks"
	@echo ""
	@echo "📚 Examples:"
	@echo "  examples  - Run all example scenarios"
	@echo ""
	@echo "🧹 Cleanup:"
	@echo "  clean     - Clean up demo environment"
	@echo ""

# Set up the demo environment
setup:
	@echo "Setting up OCM demo environment..."
	@./scripts/setup-environment.sh

# Run the quick demo
demo:
	@echo "Running OCM demo..."
	@./scripts/quick-demo.sh

# Run all tests
test:
	@echo "Running all tests..."
	@./scripts/test-all.sh

# Validate scripts and documentation
validate:
	@echo "Validating project structure..."
	@./scripts/validate-structure.sh

# Run shellcheck on all scripts
lint:
	@echo "Running shellcheck on all scripts..."
	@find . -name "*.sh" -type f -exec shellcheck {} \;

# Run all validation checks
check: lint validate
	@echo "✅ All checks completed"

# Run all examples
examples:
	@echo "Running all example scenarios..."
	@for dir in examples/*/; do \
		if [ -f "$$dir/run-examples.sh" ]; then \
			echo "Running examples in $$dir"; \
			cd "$$dir" && ./run-examples.sh && cd - > /dev/null; \
		fi \
	done

# Clean up demo environment
clean:
	@echo "Cleaning up demo environment..."
	@./scripts/test-all.sh cleanup