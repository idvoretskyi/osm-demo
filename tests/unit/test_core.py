"""
Unit tests for OCM Demo core functionality.
"""

import pytest
from unittest.mock import Mock, patch
from src.core.demo import DemoRunner
from src.core.environment import EnvironmentManager

class TestDemoRunner:
    """Test demo runner functionality."""
    
    def test_list_available_examples(self, temp_dir):
        """Test listing available examples."""
        # Create mock example directories
        examples_dir = temp_dir / "examples"
        examples_dir.mkdir()
        
        (examples_dir / "01-basic").mkdir()
        (examples_dir / "02-transport").mkdir()
        (examples_dir / ".hidden").mkdir()  # Should be ignored
        
        with patch.object(DemoRunner, 'examples_dir', examples_dir):
            runner = DemoRunner(dry_run=True)
            examples = runner.list_available_examples()
            
            assert "01-basic" in examples
            assert "02-transport" in examples
            assert ".hidden" not in examples
    
    @patch('src.core.demo.DemoRunner._check_environment')
    def test_run_quick_demo_environment_check(self, mock_check):
        """Test that demo checks environment before running."""
        mock_check.return_value = False
        
        runner = DemoRunner(dry_run=True)
        result = runner.run_quick_demo(interactive=False)
        
        assert result == False
        mock_check.assert_called_once()
    
    def test_get_demo_status(self):
        """Test demo status retrieval."""
        with patch.object(DemoRunner, 'list_available_examples') as mock_list, \
             patch('src.core.demo.EnvironmentManager') as mock_env_class:
            
            mock_list.return_value = ["01-basic", "02-transport"]
            mock_env = Mock()
            mock_env.get_environment_status.return_value = {
                'ready': True,
                'prerequisites': {'docker': True, 'ocm': True}
            }
            mock_env_class.return_value = mock_env
            
            runner = DemoRunner(dry_run=True)
            status = runner.get_demo_status()
            
            assert status['examples_count'] == 2
            assert status['ready_for_demo'] == True

class TestEnvironmentManager:
    """Test environment management functionality."""
    
    def test_check_prerequisites(self):
        """Test prerequisite checking."""
        with patch('src.utils.commands.command_exists') as mock_exists, \
             patch('src.core.environment.DockerManager') as mock_docker_class, \
             patch('src.core.environment.OCMClient') as mock_ocm_class:
            
            # Mock command existence
            mock_exists.side_effect = lambda cmd: cmd in ['curl', 'git']
            
            # Mock Docker and OCM availability
            mock_docker = Mock()
            mock_docker.check_docker_available.return_value = True
            mock_docker_class.return_value = mock_docker
            
            mock_ocm = Mock()
            mock_ocm.check_ocm_available.return_value = False
            mock_ocm_class.return_value = mock_ocm
            
            manager = EnvironmentManager(dry_run=True)
            prerequisites = manager.check_prerequisites()
            
            assert prerequisites['docker'] == True
            assert prerequisites['ocm'] == False
            assert prerequisites['curl'] == True
            assert prerequisites['git'] == True
    
    @patch('platform.system')
    @patch('platform.machine')
    def test_install_ocm_cli_platform_detection(self, mock_machine, mock_system):
        """Test OCM CLI installation platform detection."""
        mock_system.return_value = "Darwin"
        mock_machine.return_value = "arm64"
        
        manager = EnvironmentManager(dry_run=True)
        
        with patch.object(manager, '_download_and_install_ocm') as mock_download:
            mock_download.return_value = True
            result = manager.install_ocm_cli()
            
            mock_download.assert_called_once_with("darwin", "arm64")
            assert result == True
