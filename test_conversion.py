#!/usr/bin/env python3
"""
Simple test script for OCM Demo Playground Python conversion.
"""

import sys
import os
from pathlib import Path

# Add src to path
src_dir = Path(__file__).parent / "src"
sys.path.insert(0, str(src_dir))

def test_imports():
    """Test that all modules can be imported."""
    try:
        print("Testing imports...")
        
        # Test utils imports
        from src.utils.config import Config, get_config
        from src.utils.logging import setup_logging, get_logger
        from src.utils.commands import CommandRunner, command_exists
        print("✅ Utils imports successful")
        
        # Test core imports
        from src.core.environment import EnvironmentManager
        from src.core.demo import DemoRunner
        print("✅ Core imports successful")
        
        # Test CLI imports
        from src.cli.commands import main
        print("✅ CLI imports successful")
        
        return True
        
    except ImportError as e:
        print(f"❌ Import failed: {e}")
        return False

def test_basic_functionality():
    """Test basic functionality."""
    try:
        print("\nTesting basic functionality...")
        
        # Test configuration
        from src.utils.config import Config
        config = Config()
        print(f"✅ Config created: registry_port={config.registry_port}")
        
        # Test logging
        from src.utils.logging import setup_logging
        logger = setup_logging("INFO")
        logger.info("Test log message")
        print("✅ Logging working")
        
        # Test command runner (dry run)
        from src.utils.commands import CommandRunner
        runner = CommandRunner(dry_run=True)
        result = runner.run("echo test")
        print(f"✅ Command runner working: returncode={result.returncode}")
        
        return True
        
    except Exception as e:
        print(f"❌ Functionality test failed: {e}")
        return False

def test_cli_help():
    """Test CLI help functionality."""
    try:
        print("\nTesting CLI help...")
        
        from src.cli.commands import create_parser
        parser = create_parser()
        help_text = parser.format_help()
        
        if "OCM Demo Playground" in help_text:
            print("✅ CLI help working")
            return True
        else:
            print("❌ CLI help missing expected content")
            return False
            
    except Exception as e:
        print(f"❌ CLI test failed: {e}")
        return False

def main():
    """Run all tests."""
    print("OCM Demo Playground - Python Conversion Test")
    print("=" * 50)
    
    success = True
    
    success &= test_imports()
    success &= test_basic_functionality() 
    success &= test_cli_help()
    
    print("\n" + "=" * 50)
    if success:
        print("🎉 All tests passed! Python conversion is working.")
        print("\nNext steps:")
        print("  1. Install dependencies: pip install -r requirements.txt")
        print("  2. Run setup: python main.py setup")
        print("  3. Run demo: python main.py demo")
    else:
        print("❌ Some tests failed. Check the errors above.")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
