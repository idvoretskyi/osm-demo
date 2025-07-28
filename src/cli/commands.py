"""
Main CLI commands for OCM Demo Playground.
"""

import argparse
import sys
from typing import Optional

from ..core.demo import DemoRunner
from ..core.environment import EnvironmentManager
from ..utils.config import get_config
from ..utils.logging import get_logger, log_error, log_info, log_success, setup_logging

def setup_command(args) -> int:
    """Setup environment command."""
    setup_logging(args.log_level)
    
    env_manager = EnvironmentManager(dry_run=args.dry_run)
    
    log_info("Setting up OCM Demo environment...")
    success = env_manager.setup_environment(install_missing=not args.check_only)
    
    if args.check_only:
        status = env_manager.get_environment_status()
        print("\nEnvironment Status:")
        print(f"  Ready for demo: {'✅' if status['ready'] else '❌'}")
        print("\nPrerequisites:")
        for tool, available in status['prerequisites'].items():
            status_icon = '✅' if available else '❌'
            print(f"  {tool}: {status_icon}")
        
        print(f"\nRegistry: {'✅ Running' if status['registry']['running'] else '❌ Not running'}")
        
        if status['ocm_version']:
            print(f"OCM Version: {status['ocm_version']}")
        
        return 0 if status['ready'] else 1
    
    return 0 if success else 1

def demo_command(args) -> int:
    """Run demo command."""
    setup_logging(args.log_level)
    
    demo_runner = DemoRunner(dry_run=args.dry_run)
    
    if args.example:
        success = demo_runner.run_specific_example(args.example)
    else:
        success = demo_runner.run_quick_demo(interactive=not args.non_interactive)
    
    return 0 if success else 1

def test_command(args) -> int:
    """Run test command."""
    setup_logging(args.log_level)
    
    demo_runner = DemoRunner(dry_run=args.dry_run)
    
    if args.example:
        success = demo_runner.run_specific_example(args.example)
    else:
        success = demo_runner.run_all_tests()
    
    return 0 if success else 1

def list_command(args) -> int:
    """List examples command."""
    setup_logging(args.log_level)
    
    demo_runner = DemoRunner(dry_run=args.dry_run)
    examples = demo_runner.list_available_examples()
    
    if examples:
        print("Available examples:")
        for example in examples:
            print(f"  - {example}")
    else:
        print("No examples found")
    
    return 0

def status_command(args) -> int:
    """Show status command."""
    setup_logging(args.log_level)
    
    demo_runner = DemoRunner(dry_run=args.dry_run)
    status = demo_runner.get_demo_status()
    
    print("OCM Demo Playground Status")
    print("=" * 40)
    
    env = status['environment']
    print(f"Environment Ready: {'✅' if env['ready'] else '❌'}")
    
    print("\nPrerequisites:")
    for tool, available in env['prerequisites'].items():
        status_icon = '✅' if available else '❌'
        print(f"  {tool}: {status_icon}")
    
    registry = env['registry']
    print(f"\nRegistry:")
    print(f"  Running: {'✅' if registry['running'] else '❌'}")
    print(f"  URL: {registry['url']}")
    print(f"  Port: {registry['port']}")
    
    if env['ocm_version']:
        print(f"\nOCM Version: {env['ocm_version']}")
    
    print(f"\nAvailable Examples: {status['examples_count']}")
    if args.verbose:
        for example in status['available_examples']:
            print(f"  - {example}")
    
    return 0

def cleanup_command(args) -> int:
    """Cleanup environment command."""
    setup_logging(args.log_level)
    
    env_manager = EnvironmentManager(dry_run=args.dry_run)
    
    log_info("Cleaning up OCM Demo environment...")
    success = env_manager.cleanup_environment()
    
    return 0 if success else 1

def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser."""
    parser = argparse.ArgumentParser(
        prog='ocm-demo',
        description='OCM Demo Playground - Interactive demonstrations of Open Component Model capabilities'
    )
    
    # Global options
    parser.add_argument(
        '--log-level',
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        default='INFO',
        help='Set logging level (default: INFO)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without executing commands'
    )
    
    # Subcommands
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Setup command
    setup_parser = subparsers.add_parser('setup', help='Set up the demo environment')
    setup_parser.add_argument(
        '--check-only',
        action='store_true',
        help='Only check prerequisites without installing anything'
    )
    setup_parser.set_defaults(func=setup_command)
    
    # Demo command
    demo_parser = subparsers.add_parser('demo', help='Run the interactive demo')
    demo_parser.add_argument(
        '--example',
        help='Run a specific example instead of the full demo'
    )
    demo_parser.add_argument(
        '--non-interactive',
        action='store_true',
        help='Run demo without interactive pauses'
    )
    demo_parser.set_defaults(func=demo_command)
    
    # Test command
    test_parser = subparsers.add_parser('test', help='Run the test suite')
    test_parser.add_argument(
        '--example',
        help='Test a specific example instead of all tests'
    )
    test_parser.set_defaults(func=test_command)
    
    # List command
    list_parser = subparsers.add_parser('list', help='List available examples')
    list_parser.set_defaults(func=list_command)
    
    # Status command
    status_parser = subparsers.add_parser('status', help='Show environment status')
    status_parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Show detailed status information'
    )
    status_parser.set_defaults(func=status_command)
    
    # Cleanup command
    cleanup_parser = subparsers.add_parser('cleanup', help='Clean up demo environment')
    cleanup_parser.set_defaults(func=cleanup_command)
    
    return parser

def main(argv: Optional[list] = None) -> int:
    """
    Main CLI entry point.
    
    Args:
        argv: Command line arguments (defaults to sys.argv[1:])
        
    Returns:
        Exit code (0 for success, non-zero for failure)
    """
    parser = create_parser()
    args = parser.parse_args(argv)
    
    # If no command specified, show help
    if not args.command:
        parser.print_help()
        return 1
    
    try:
        return args.func(args)
    except KeyboardInterrupt:
        log_info("Operation cancelled by user")
        return 130
    except Exception as e:
        log_error(f"Unexpected error: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
