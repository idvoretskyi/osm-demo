"""
Environment management for OCM Demo Playground.
Handles prerequisite checking, tool installation, and environment setup.
Converts functionality from setup-environment.sh
"""

import os
import platform
import sys
import tempfile
import urllib.request
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from ..utils.commands import CommandRunner, command_exists
from ..utils.config import get_config
from ..utils.docker_utils import DockerManager
from ..utils.logging import get_logger, log_error, log_info, log_success, log_warning
from ..utils.ocm_utils import OCMClient

logger = get_logger('environment')

class EnvironmentManager:
    """Manages environment setup and prerequisites for OCM Demo."""
    
    def __init__(self, dry_run: bool = False):
        """
        Initialize EnvironmentManager.
        
        Args:
            dry_run: If True, commands will be logged but not executed
        """
        self.runner = CommandRunner(dry_run=dry_run)
        self.config = get_config()
        self.docker = DockerManager(dry_run=dry_run)
        self.ocm = OCMClient(dry_run=dry_run)
        self.dry_run = dry_run
    
    def check_prerequisites(self) -> Dict[str, bool]:
        """
        Check all prerequisites for the OCM demo.
        
        Returns:
            Dictionary mapping prerequisite names to availability status
        """
        log_info("Checking prerequisites...")
        
        prerequisites = {
            'docker': self.docker.check_docker_available(),
            'ocm': self.ocm.check_ocm_available(),
            'curl': command_exists('curl'),
            'kubectl': command_exists('kubectl'),
            'kind': command_exists('kind'),
            'git': command_exists('git')
        }
        
        # Log results
        for tool, available in prerequisites.items():
            if available:
                log_success(f"{tool} is available")
            else:
                log_warning(f"{tool} is not available")
        
        return prerequisites
    
    def setup_environment(self, install_missing: bool = True) -> bool:
        """
        Set up the complete environment for OCM demo.
        
        Args:
            install_missing: Whether to install missing tools
            
        Returns:
            True if environment setup successful, False otherwise
        """
        log_info("Setting up OCM Demo environment...")
        
        success = True
        
        # Check and install prerequisites
        prerequisites = self.check_prerequisites()
        
        if install_missing:
            # Install OCM CLI if missing
            if not prerequisites.get('ocm', False):
                if not self.install_ocm_cli():
                    success = False
            
            # Check for other missing tools
            missing_tools = [tool for tool, available in prerequisites.items() 
                           if not available and tool != 'ocm']
            
            if missing_tools:
                log_warning(f"Missing tools: {', '.join(missing_tools)}")
                log_info("Please install the missing tools manually:")
                for tool in missing_tools:
                    log_info(f"  - {tool}: {self._get_install_hint(tool)}")
        
        # Set up local registry
        if prerequisites.get('docker', False):
            if not self.docker.start_registry():
                log_warning("Failed to start local registry")
                success = False
        
        if success:
            log_success("Environment setup completed successfully!")
        else:
            log_error("Environment setup completed with some issues")
        
        return success
    
    def install_ocm_cli(self) -> bool:
        """
        Install OCM CLI for the current platform.
        
        Returns:
            True if installation successful, False otherwise
        """
        if command_exists('ocm'):
            log_success("OCM CLI is already installed")
            return True
        
        log_info("Installing OCM CLI...")
        
        try:
            # Detect OS and architecture
            os_name = platform.system().lower()
            arch = platform.machine().lower()
            
            # Map architecture names
            if arch in ['x86_64', 'amd64']:
                arch = 'amd64'
            elif arch in ['arm64', 'aarch64']:
                arch = 'arm64'
            else:
                log_error(f"Unsupported architecture: {arch}")
                return False
            
            # Map OS names
            if os_name == 'darwin':
                os_name = 'darwin'
            elif os_name == 'linux':
                os_name = 'linux'
            elif os_name == 'windows':
                os_name = 'windows'
            else:
                log_error(f"Unsupported operating system: {os_name}")
                return False
            
            # Download and install
            return self._download_and_install_ocm(os_name, arch)
            
        except Exception as e:
            log_error(f"Failed to install OCM CLI: {e}")
            return False
    
    def _download_and_install_ocm(self, os_name: str, arch: str) -> bool:
        """
        Download and install OCM CLI binary.
        
        Args:
            os_name: Operating system name
            arch: Architecture name
            
        Returns:
            True if installation successful, False otherwise
        """
        # Get latest release info from GitHub API
        api_url = "https://api.github.com/repos/open-component-model/ocm/releases/latest"
        
        try:
            with urllib.request.urlopen(api_url) as response:
                import json
                release_data = json.loads(response.read().decode())
            
            # Find the appropriate asset
            binary_name = f"ocm-{release_data['tag_name']}-{os_name}-{arch}"
            if os_name == 'windows':
                binary_name += '.exe'
            
            download_url = None
            for asset in release_data['assets']:
                if binary_name in asset['name']:
                    download_url = asset['browser_download_url']
                    break
            
            if not download_url:
                log_error(f"No suitable OCM CLI binary found for {os_name}-{arch}")
                return False
            
            # Download binary
            log_info(f"Downloading OCM CLI from {download_url}")
            
            with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
                with urllib.request.urlopen(download_url) as response:
                    tmp_file.write(response.read())
                tmp_path = tmp_file.name
            
            # Install binary
            install_dir = self._get_install_directory()
            os.makedirs(install_dir, exist_ok=True)
            
            binary_name = 'ocm'
            if os_name == 'windows':
                binary_name += '.exe'
            
            install_path = os.path.join(install_dir, binary_name)
            
            # Move binary to install location
            if self.dry_run:
                log_info(f"[DRY RUN] Would install OCM CLI to {install_path}")
            else:
                os.rename(tmp_path, install_path)
                os.chmod(install_path, 0o755)
            
            # Verify installation
            if command_exists('ocm') or self.dry_run:
                log_success(f"OCM CLI installed successfully to {install_path}")
                return True
            else:
                log_error(f"OCM CLI installation failed - binary not found in PATH")
                log_info(f"You may need to add {install_dir} to your PATH")
                return False
                
        except Exception as e:
            log_error(f"Failed to download OCM CLI: {e}")
            return False
    
    def _get_install_directory(self) -> str:
        """
        Get the appropriate installation directory for the current platform.
        
        Returns:
            Installation directory path
        """
        if platform.system().lower() == 'windows':
            # On Windows, use a directory in user profile
            return os.path.join(os.path.expanduser('~'), 'bin')
        else:
            # On Unix-like systems, try to use a directory in PATH
            path_dirs = os.environ.get('PATH', '').split(os.pathsep)
            
            # Prefer user-local directories
            home = os.path.expanduser('~')
            preferred_dirs = [
                os.path.join(home, '.local', 'bin'),
                os.path.join(home, 'bin'),
                '/usr/local/bin'
            ]
            
            for dir_path in preferred_dirs:
                if dir_path in path_dirs and os.access(os.path.dirname(dir_path), os.W_OK):
                    return dir_path
            
            # Fall back to ~/.local/bin
            return os.path.join(home, '.local', 'bin')
    
    def _get_install_hint(self, tool: str) -> str:
        """
        Get installation hint for a specific tool.
        
        Args:
            tool: Tool name
            
        Returns:
            Installation hint string
        """
        hints = {
            'docker': 'https://docs.docker.com/get-docker/',
            'kubectl': 'https://kubernetes.io/docs/tasks/tools/install-kubectl/',
            'kind': 'https://kind.sigs.k8s.io/docs/user/quick-start/#installation',
            'curl': 'Install curl using your system package manager',
            'git': 'https://git-scm.com/downloads'
        }
        
        return hints.get(tool, f'Please install {tool} manually')
    
    def cleanup_environment(self) -> bool:
        """
        Clean up the demo environment.
        
        Returns:
            True if cleanup successful, False otherwise
        """
        log_info("Cleaning up demo environment...")
        
        success = True
        
        # Stop local registry
        if not self.docker.stop_registry():
            success = False
        
        # TODO: Add cleanup for kind clusters, temporary files, etc.
        
        if success:
            log_success("Environment cleanup completed successfully!")
        else:
            log_warning("Environment cleanup completed with some issues")
        
        return success
    
    def get_environment_status(self) -> Dict[str, any]:
        """
        Get comprehensive environment status.
        
        Returns:
            Dictionary with environment status information
        """
        prerequisites = self.check_prerequisites()
        registry_status = self.docker.get_registry_status()
        
        return {
            'prerequisites': prerequisites,
            'registry': registry_status,
            'ocm_version': self.ocm.get_version(),
            'ready': all(prerequisites.values()) and registry_status.get('running', False)
        }
