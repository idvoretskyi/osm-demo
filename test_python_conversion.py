#!/usr/bin/env python3
"""
Simple test script to verify the Python conversion works.
"""

import sys
import os
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

def test_imports():
    """Test if all modules can be imported."""
    tests = []
    
    # Test utils modules
    try:
        from utils.logging import get_logger, log_info
        tests.append(("utils.logging", True, None))
    except Exception as e:
        tests.append(("utils.logging", False, str(e)))
    
    try:
        from utils.config import Config, get_config
        tests.append(("utils.config", True, None))
    except Exception as e:
        tests.append(("utils.config", False, str(e)))
        
    try:
        from utils.commands import CommandRunner
        tests.append(("utils.commands", True, None))
    except Exception as e:
        tests.append(("utils.commands", False, str(e)))
        
    try:
        from utils.docker_utils import DockerManager
        tests.append(("utils.docker_utils", True, None))
    except Exception as e:
        tests.append(("utils.docker_utils", False, str(e)))
        
    try:
        from utils.ocm_utils import OCMClient
        tests.append(("utils.ocm_utils", True, None))
    except Exception as e:
        tests.append(("utils.ocm_utils", False, str(e)))
    
    # Test core modules
    try:
        from core.environment import EnvironmentManager
        tests.append(("core.environment", True, None))
    except Exception as e:
        tests.append(("core.environment", False, str(e)))
        
    try:
        from core.demo import DemoRunner
        tests.append(("core.demo", True, None))
    except Exception as e:
        tests.append(("core.demo", False, str(e)))
    
    # Test CLI
    try:
        from cli.commands import main
        tests.append(("cli.commands", True, None))
    except Exception as e:
        tests.append(("cli.commands", False, str(e)))
    
    return tests

def test_basic_functionality():
    """Test basic functionality."""
    try:
        from utils.config import get_config
        config = get_config()
        print(f"✅ Configuration loaded: registry_port={config.registry_port}")
        return True
    except Exception as e:
        print(f"❌ Configuration test failed: {e}")
        return False

def main():
    """Run all tests."""
    print("🧪 Testing Python OCM Demo Conversion")
    print("=" * 50)
    
    # Test imports
    print("\n📦 Testing Module Imports:")
    tests = test_imports()
    passed = 0
    failed = 0
    
    for module_name, success, error in tests:
        if success:
            print(f"  ✅ {module_name}")
            passed += 1
        else:
            print(f"  ❌ {module_name}: {error}")
            failed += 1
    
    print(f"\nImport Results: {passed} passed, {failed} failed")
    
    # Test basic functionality
    print("\n⚙️  Testing Basic Functionality:")
    func_test = test_basic_functionality()
    
    # Overall result
    print(f"\n🎯 Overall Result:")
    if failed == 0 and func_test:
        print("✅ All tests passed! The Python conversion is working.")
        return 0
    else:
        print("❌ Some tests failed. Check the errors above.")
        return 1

if __name__ == '__main__':
    sys.exit(main())
