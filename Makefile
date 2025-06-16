# OCM Demo Makefile
# Simple commands for the demo

.PHONY: help setup demo clean

# Default target
help:
	@echo "OCM Demo - Available commands:"
	@echo ""
	@echo "  setup     - Set up the demo environment"
	@echo "  demo      - Run the demo examples"
	@echo "  clean     - Clean up demo environment"
	@echo ""

# Set up the demo environment
setup:
	@echo "Setting up OCM demo environment..."
	@./scripts/setup-environment.sh

# Run the demo
demo:
	@echo "Running OCM demo..."
	@./scripts/quick-demo.sh

# Clean up demo environment
clean:
	@echo "Cleaning up demo environment..."
	@./scripts/test-all.sh cleanup