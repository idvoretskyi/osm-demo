# Contributing to OCM Demo Playground

We welcome contributions to the OCM Demo Playground! This document provides guidelines for contributing to this project.

## 🤝 Types of Contributions

We appreciate various types of contributions:

- 🐛 **Bug Reports**: Report issues with existing examples or scripts
- ✨ **New Examples**: Add new OCM use cases and scenarios
- 📚 **Documentation**: Improve guides, READMEs, and troubleshooting
- 🔧 **Script Improvements**: Enhance automation and utility scripts
- 🧪 **Testing**: Add tests for examples and validate workflows
- 💡 **Ideas**: Suggest new features or improvements

## 🚀 Getting Started

### 1. Fork and Clone

1. Fork this repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/osm-demo.git
   cd osm-demo
   ```

### 2. Set Up Development Environment

1. Run the environment setup:
   ```bash
   ./scripts/setup-environment.sh
   ```

2. Test that all examples work:
   ```bash
   ./scripts/ocm-utils.sh --run-all
   ```

### 3. Create a Branch

Create a descriptive branch for your work:
```bash
git checkout -b feature/add-helm-example
# or
git checkout -b fix/registry-connection-issue
# or
git checkout -b docs/improve-troubleshooting
```

## 📝 Contribution Guidelines

### Code Style

- **Shell Scripts**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **Bash Best Practices**: Use `set -euo pipefail` for error handling
- **Formatting**: Use consistent indentation (2 spaces for shell scripts)
- **Comments**: Add meaningful comments explaining complex logic

Example shell script header:
```bash
#!/bin/bash
set -euo pipefail

# Description: Example script for demonstrating OCM feature
# Usage: ./script-name.sh [options]
# Dependencies: ocm, docker

# Enable colored output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color
```

### Directory Structure

When adding new examples, follow the established structure:

```
examples/
├── XX-category/              # Use incremental numbering
│   ├── README.md            # Category overview and learning objectives
│   ├── run-examples.sh      # Script to run all examples in category
│   ├── example-name/        # Individual example directory
│   │   ├── README.md        # Example-specific documentation
│   │   ├── script-name.sh   # Main executable script
│   │   ├── resources/       # Example resources (configs, manifests)
│   │   └── expected-output/ # Sample output for testing
│   └── ...
```

### Documentation Standards

- **README Files**: Each example must have a clear README explaining:
  - Purpose and learning objectives
  - Prerequisites
  - Step-by-step instructions
  - Expected outcomes
  - Troubleshooting tips

- **Comments in Scripts**: 
  - Explain what each section does
  - Include usage examples
  - Document any assumptions or requirements

- **Mermaid Diagrams**: Update flow diagrams when adding new examples

### Testing Requirements

All contributions should be tested:

1. **Manual Testing**: Run your example end-to-end
2. **Error Scenarios**: Test with missing dependencies or incorrect setup
3. **Cleanup**: Ensure scripts properly clean up resources
4. **Cross-Platform**: Test on different operating systems if possible

### Example Template

When creating new examples, use this template structure:

```bash
#!/bin/bash
set -euo pipefail

# Example: [Brief description]
# Category: [Basic|Transport|Signing|K8s|Advanced]
# Prerequisites: [List requirements]
# Learning objectives:
# - [Objective 1]
# - [Objective 2]

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly DEMO_DIR="/tmp/ocm-demo"
readonly COMPONENT_NAME="example-component"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

cleanup() {
    log_info "Cleaning up..."
    # Add cleanup logic here
}

# Set up cleanup trap
trap cleanup EXIT

main() {
    log_info "Starting [Example Name]..."
    
    # Prerequisites check
    if ! command -v ocm &> /dev/null; then
        log_error "OCM CLI not found. Please run ./scripts/setup-environment.sh"
        exit 1
    fi
    
    # Main logic here
    
    log_success "Example completed successfully!"
}

# Run main function
main "$@"
```

## 🧪 Adding New Examples

### Example Categories

- **01-Basic**: Fundamental OCM concepts (components, resources, metadata)
- **02-Transport**: Moving components between repositories and registries
- **03-Signing**: Security, signatures, and verification
- **04-K8s-Deployment**: Kubernetes integration and deployment patterns
- **05-Advanced**: Complex scenarios, custom integrations, production patterns

### Example Requirements

Each example should:

1. **Have a clear learning objective**
2. **Be self-contained** (include all necessary resources)
3. **Include error handling** and helpful error messages
4. **Provide colored, informative output**
5. **Clean up resources** after completion
6. **Be idempotent** (can be run multiple times safely)

### Example Checklist

Before submitting a new example:

- [ ] Script is executable (`chmod +x`)
- [ ] Follows shell script best practices
- [ ] Includes comprehensive error handling
- [ ] Has colored output for better UX
- [ ] Cleans up resources on exit
- [ ] Includes detailed README
- [ ] Tests pass in clean environment
- [ ] Updates category `run-examples.sh` script
- [ ] Updates main documentation if needed

## 🔍 Pull Request Process

### Before Submitting

1. **Test thoroughly**: Run your changes in a clean environment
2. **Update documentation**: Ensure README files are current
3. **Check script permissions**: Make sure scripts are executable
4. **Validate examples**: Ensure all examples in your category still work
5. **Update flow diagrams**: Add your example to relevant mermaid diagrams

### Pull Request Template

Use this template for your PR description:

```markdown
## Summary
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New example
- [ ] Documentation update
- [ ] Script improvement
- [ ] Other (specify)

## Learning Objectives
What will users learn from this contribution?
- [Objective 1]
- [Objective 2]

## Testing
- [ ] Tested in clean environment
- [ ] All examples in category work
- [ ] Error scenarios tested
- [ ] Documentation updated

## Dependencies
List any new dependencies or requirements

## Related Issues
Fixes #[issue number] (if applicable)
```

### Review Process

1. **Automated checks** will validate basic requirements
2. **Maintainer review** for code quality and educational value
3. **Testing** in multiple environments
4. **Documentation review** for clarity and completeness
5. **Merge** after approval

## 🐛 Reporting Bugs

When reporting bugs, please include:

### Issue Template

```markdown
## Bug Description
Clear description of the issue

## Environment
- OS: [e.g., macOS 13.5, Ubuntu 22.04]
- OCM CLI version: [ocm version]
- Docker version: [docker --version]
- Kind version: [kind --version]

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Error Messages
```
[Include any error messages or logs]
```

## Additional Context
Any other relevant information
```

## 💡 Suggesting Features

For new features or improvements:

1. **Check existing issues** to avoid duplicates
2. **Describe the use case** and learning value
3. **Provide examples** of how it would work
4. **Consider implementation complexity**

## 🎯 Coding Standards

### Shell Scripts

- Use `#!/bin/bash` shebang
- Include `set -euo pipefail` for error handling
- Use meaningful variable names
- Quote variables to prevent word splitting
- Use readonly for constants
- Include function documentation

### Documentation

- Use clear, concise language
- Include code examples
- Add visual aids (diagrams) when helpful
- Keep learning objectives specific and measurable

### Error Handling

- Always check command success
- Provide helpful error messages
- Include troubleshooting hints
- Clean up resources on failure

## 🏆 Recognition

Contributors will be recognized in:

- GitHub contributor list
- README acknowledgments
- Release notes for significant contributions

## 📞 Getting Help

Need help with your contribution?

- **GitHub Discussions**: Ask questions in [GitHub Discussions](https://github.com/open-component-model/community/discussions)
- **OCM Community**: Join the [OCM Community](https://github.com/open-component-model/community)
- **Slack**: OCM Community Slack (link in community repo)

## 📄 License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

Thank you for contributing to the OCM Demo Playground! 🎉
