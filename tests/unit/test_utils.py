"""
Unit tests for OCM Demo utilities.
"""

import pytest
from unittest.mock import Mock, patch
from src.utils.config import Config
from src.utils.commands import CommandRunner, command_exists
from src.utils.logging import setup_logging, get_logger

class TestConfig:
    """Test configuration management."""
    
    def test_default_config(self):
        """Test default configuration values."""
        config = Config()
        assert config.registry_port == 5001
        assert config.cluster_name == "ocm-demo"
        assert config.namespace == "ocm-demos"
    
    def test_config_from_environment(self, mock_env):
        """Test configuration from environment variables."""
        config = Config.from_environment()
        assert config.registry_port == 5555
        assert config.cluster_name == "test-cluster"
        assert config.namespace == "test-namespace"
    
    def test_registry_url(self):
        """Test registry URL generation."""
        config = Config(registry_host="example.com", registry_port=8080)
        assert config.registry_url == "example.com:8080"

class TestCommandRunner:
    """Test command execution utilities."""
    
    def test_command_exists(self):
        """Test command existence checking."""
        # Test with a command that should exist
        assert command_exists("echo") == True
        
        # Test with a command that shouldn't exist
        assert command_exists("nonexistent-command-12345") == False
    
    def test_dry_run_mode(self):
        """Test dry run mode."""
        runner = CommandRunner(dry_run=True)
        result = runner.run("echo test")
        assert result.returncode == 0
        assert result.stdout == ""
    
    @patch('subprocess.run')
    def test_command_execution(self, mock_run):
        """Test actual command execution."""
        # Mock successful command
        mock_run.return_value = Mock(returncode=0, stdout="success", stderr="")
        
        runner = CommandRunner(dry_run=False)
        result = runner.run(["echo", "test"])
        
        assert result.returncode == 0
        mock_run.assert_called_once()

class TestLogging:
    """Test logging utilities."""
    
    def test_setup_logging(self):
        """Test logging setup."""
        logger = setup_logging("INFO")
        assert logger.name == "ocm_demo"
        assert logger.level == 20  # INFO level
    
    def test_get_logger(self):
        """Test logger retrieval."""
        logger = get_logger("test")
        assert logger.name == "ocm_demo.test"
        
        main_logger = get_logger()
        assert main_logger.name == "ocm_demo"
