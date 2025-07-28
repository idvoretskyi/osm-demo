# OCM Demo Playground - Python Conversion Guide

This document describes the conversion of the OCM Demo Playground from Bash scripts to Python and Terraform.

## Overview

The OCM Demo Playground has been successfully converted from a collection of Bash scripts to a structured Python application with Terraform infrastructure management. This conversion provides:

- **Better Error Handling**: Comprehensive error handling and logging
- **Cross-Platform Compatibility**: Works on Windows, macOS, and Linux
- **Improved Maintainability**: Modular, well-documented Python code
- **Enhanced Testing**: Unit and integration test suites
- **Infrastructure as Code**: Terraform modules for reproducible environments

## Project Structure

```
ocm-demo/
├── src/                     # Python source code
│   ├── core/               # Core functionality
│   │   ├── demo.py         # Demo orchestration (from quick-demo.sh)
│   │   └── environment.py  # Environment management (from setup-environment.sh)
│   ├── utils/              # Utility modules
│   │   ├── commands.py     # Command execution (from common.sh)
│   │   ├── config.py       # Configuration management
│   │   ├── docker_utils.py # Docker operations
│   │   ├── logging.py      # Logging utilities
│   │   └── ocm_utils.py    # OCM CLI operations (from ocm-utils.sh)
│   └── cli/                # Command-line interface
│       └── commands.py     # CLI commands
├── terraform/              # Infrastructure as Code
│   ├── modules/           # Reusable Terraform modules
│   └── environments/      # Environment-specific configurations
├── tests/                  # Test suites
│   ├── unit/              # Unit tests
│   └── integration/       # Integration tests
├── config/                 # Configuration files
├── examples/              # Demo examples (unchanged)
├── main.py               # Main entry point
├── requirements.txt      # Python dependencies
└── Makefile             # Development commands
```

## Conversion Mapping

### Scripts Converted

| Original Bash Script | Python Module | Description |
|---------------------|---------------|-------------|
| `scripts/common.sh` | `src/utils/` | Shared utilities and functions |
| `scripts/setup-environment.sh` | `src/core/environment.py` | Environment setup and tool installation |
| `scripts/quick-demo.sh` | `src/core/demo.py` | Interactive demo orchestration |
| `scripts/test-all.sh` | `src/core/demo.py` | Comprehensive testing functionality |
| `scripts/ocm-utils.sh` | `src/utils/ocm_utils.py` | OCM CLI operations |
| Various example scripts | `src/core/demo.py` | Example execution and management |

### Key Improvements

1. **Error Handling**: Comprehensive exception handling and user-friendly error messages
2. **Logging**: Structured logging with colored output and different verbosity levels  
3. **Configuration**: YAML-based configuration with environment variable overrides
4. **Testing**: Unit and integration tests with pytest framework
5. **Documentation**: Comprehensive docstrings and type hints
6. **Cross-Platform**: Works on Windows, macOS, and Linux without modifications

## Usage

### Installation

```bash
# Install Python dependencies
make install

# Or manually
pip install -r requirements.txt
pip install -e .
```

### Basic Commands

```bash
# Set up the environment
python main.py setup

# Run the interactive demo
python main.py demo

# Run all tests
python main.py test

# Show environment status
python main.py status

# Clean up
python main.py cleanup
```

### Advanced Usage

```bash
# Run a specific example
python main.py demo --example 01-basic

# Run in non-interactive mode
python main.py demo --non-interactive

# Check environment without installing anything
python main.py setup --check-only

# Run with debug logging
python main.py --log-level DEBUG status

# Dry run mode (show what would be done)
python main.py --dry-run setup
```

## Development

### Running Tests

```bash
# Unit tests
make test-unit

# Integration tests  
make test-integration

# All tests with coverage
make test-pytest
```

### Code Quality

```bash
# Format code
make format

# Lint code
make lint

# Development test cycle
make dev-test
```

### Development Setup

```bash
# Set up development environment
make dev-setup

# Show conversion status
make conversion-status
```

## Configuration

Configuration can be provided through:

1. **YAML files**: `config/default.yaml`
2. **Environment variables**: `OCM_DEMO_*` prefixed variables
3. **Command-line arguments**: Various CLI options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OCM_DEMO_REGISTRY_PORT` | Local registry port | 5001 |
| `OCM_DEMO_CLUSTER_NAME` | Kubernetes cluster name | ocm-demo |
| `OCM_DEMO_NAMESPACE` | Kubernetes namespace | ocm-demos |
| `OCM_DEMO_REGISTRY_NAME` | Registry container name | local-registry |

## Infrastructure Management

The converted application includes Terraform modules for infrastructure management:

### Registry Module

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

This creates:
- Local Docker registry container
- Proper networking configuration
- Output values for integration

## Migration from Bash Scripts

If you were using the original Bash scripts, here's how to migrate:

### Old Usage → New Usage

```bash
# Old: Bash scripts
./scripts/setup-environment.sh
./scripts/quick-demo.sh
./scripts/test-all.sh

# New: Python CLI
python main.py setup
python main.py demo  
python main.py test
```

### Environment Variables

The same environment variables are supported, so existing configurations will work without changes.

### Example Scripts

The original example scripts in `examples/` directories are still available and can be run directly, or through the new Python interface:

```bash
# Direct execution (still works)
./examples/01-basic/run-examples.sh

# Through Python interface (recommended)
python main.py demo --example 01-basic
```

## Troubleshooting

### Common Issues

1. **Python Not Found**: Ensure Python 3.8+ is installed
2. **Dependencies Missing**: Run `make install` or `pip install -r requirements.txt`
3. **Docker Issues**: Ensure Docker is running and accessible
4. **Permission Issues**: Ensure scripts are executable (`chmod +x`)

### Debug Mode

Use debug logging to troubleshoot issues:

```bash
python main.py --log-level DEBUG status
```

### Dry Run Mode

Test commands without executing them:

```bash
python main.py --dry-run setup
```

## Contributing

When contributing to the converted codebase:

1. **Follow Python Standards**: Use black for formatting, flake8 for linting
2. **Add Tests**: Include unit tests for new functionality
3. **Update Documentation**: Keep docstrings and README current
4. **Type Hints**: Use type hints for better code clarity

### Development Workflow

```bash
# 1. Make changes
# 2. Format and lint
make format lint

# 3. Run tests
make test-unit

# 4. Test integration
make test-integration
```

## Future Enhancements

The Python conversion provides a foundation for future improvements:

- **Web Interface**: Flask/FastAPI web interface for remote demos
- **Container Images**: Pre-built container images for easy deployment
- **Cloud Integration**: Support for cloud-based registries and clusters
- **Monitoring**: Built-in metrics and monitoring capabilities
- **Plugin System**: Extensible plugin architecture for custom examples

## Support

For issues related to the Python conversion:

1. Check this documentation
2. Review the troubleshooting section
3. Enable debug logging
4. File an issue with detailed error information

The conversion maintains full compatibility with the original demo workflow while providing a more robust and maintainable foundation for future development.
