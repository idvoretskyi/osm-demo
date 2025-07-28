"""
Test configuration for OCM Demo Playground.
"""

import pytest
import tempfile
import os
from pathlib import Path

@pytest.fixture
def temp_dir():
    """Create a temporary directory for tests."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)

@pytest.fixture
def mock_env():
    """Mock environment variables for testing."""
    original_env = os.environ.copy()
    
    # Set test environment variables
    test_env = {
        'OCM_DEMO_REGISTRY_PORT': '5555',
        'OCM_DEMO_CLUSTER_NAME': 'test-cluster',
        'OCM_DEMO_NAMESPACE': 'test-namespace'
    }
    
    for key, value in test_env.items():
        os.environ[key] = value
    
    yield test_env
    
    # Restore original environment
    os.environ.clear()
    os.environ.update(original_env)
