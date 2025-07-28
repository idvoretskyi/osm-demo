"""
Docker utilities for OCM Demo Playground.
Handles Docker operations including registry management.
"""

import time
from typing import Dict, List, Optional

from .commands import CommandRunner, command_exists
from .config import get_config
from .logging import get_logger, log_error, log_info, log_success, log_warning

logger = get_logger('docker')

class DockerManager:
    """Manages Docker operations for the OCM demo."""
    
    def __init__(self, dry_run: bool = False):
        """
        Initialize DockerManager.
        
        Args:
            dry_run: If True, commands will be logged but not executed
        """
        self.runner = CommandRunner(dry_run=dry_run)
        self.config = get_config()
        self.dry_run = dry_run
    
    def check_docker_available(self) -> bool:
        """
        Check if Docker is available and running.
        
        Returns:
            True if Docker is available and running, False otherwise
        """
        if not command_exists('docker'):
            log_error("Docker not found", "Please install Docker first")
            return False
        
        try:
            result = self.runner.run(['docker', 'info'], capture_output=True, check=False)
            if result.returncode != 0:
                log_error("Docker daemon not running", "Please start Docker")
                return False
            
            log_success("Docker is available and running")
            return True
            
        except Exception as e:
            log_error(f"Failed to check Docker status: {e}")
            return False
    
    def start_registry(self, port: Optional[int] = None, name: Optional[str] = None) -> bool:
        """
        Start a local Docker registry.
        
        Args:
            port: Registry port (defaults to config value)
            name: Registry container name (defaults to config value)
            
        Returns:
            True if registry started successfully, False otherwise
        """
        port = port or self.config.registry_port
        name = name or self.config.registry_name
        
        log_info(f"Starting registry on port {port}...")
        
        # Check if already running
        if self.is_registry_running(name):
            log_success("Registry already running")
            return True
        
        # Clean up any existing containers on the port
        self.cleanup_registry_port(port)
        
        # Remove existing container with same name
        self.runner.run(['docker', 'rm', '-f', name], check=False, capture_output=True)
        
        # Start new registry
        try:
            result = self.runner.run([
                'docker', 'run', '-d',
                '-p', f'{port}:5000',
                '--name', name,
                'registry:2'
            ], check=True)
            
            if result.returncode == 0:
                log_info("Waiting for registry to be ready...")
                
                # Wait for registry to be ready (up to 30 seconds)
                for i in range(30):
                    if self.is_registry_healthy(port):
                        log_success(f"Registry started successfully on port {port}")
                        return True
                    time.sleep(1)
                
                log_error("Registry failed to become healthy within 30 seconds")
                return False
            else:
                log_error("Failed to start registry container")
                return False
                
        except Exception as e:
            log_error(f"Failed to start registry: {e}")
            return False
    
    def stop_registry(self, name: Optional[str] = None) -> bool:
        """
        Stop the local Docker registry.
        
        Args:
            name: Registry container name (defaults to config value)
            
        Returns:
            True if registry stopped successfully, False otherwise
        """
        name = name or self.config.registry_name
        
        log_info(f"Stopping registry '{name}'...")
        
        try:
            # Stop and remove the container
            self.runner.run(['docker', 'stop', name], check=False, capture_output=True)
            self.runner.run(['docker', 'rm', name], check=False, capture_output=True)
            
            log_success("Registry stopped")
            return True
            
        except Exception as e:
            log_error(f"Failed to stop registry: {e}")
            return False
    
    def is_registry_running(self, name: Optional[str] = None) -> bool:
        """
        Check if registry container is running.
        
        Args:
            name: Registry container name (defaults to config value)
            
        Returns:
            True if registry is running, False otherwise
        """
        name = name or self.config.registry_name
        
        try:
            result = self.runner.run(
                ['docker', 'ps', '--format', '{{.Names}}'],
                capture_output=True,
                check=False
            )
            
            if result.returncode == 0:
                running_containers = result.stdout.strip().split('\n')
                return name in running_containers
            
            return False
            
        except Exception:
            return False
    
    def is_registry_healthy(self, port: Optional[int] = None) -> bool:
        """
        Check if registry is healthy by making a health check request.
        
        Args:
            port: Registry port (defaults to config value)
            
        Returns:
            True if registry is healthy, False otherwise
        """
        port = port or self.config.registry_port
        
        try:
            # Try to curl the registry endpoint
            result = self.runner.run([
                'curl', '-f', '-s',
                f'http://localhost:{port}/v2/'
            ], capture_output=True, check=False)
            
            return result.returncode == 0
            
        except Exception:
            return False
    
    def cleanup_registry_port(self, port: int) -> None:
        """
        Clean up any containers using the specified port.
        
        Args:
            port: Port to clean up
        """
        try:
            # Find containers using the port
            result = self.runner.run([
                'docker', 'ps', '-a',
                '--filter', f'publish={port}',
                '--format', '{{.ID}}'
            ], capture_output=True, check=False)
            
            if result.returncode == 0 and result.stdout.strip():
                container_ids = result.stdout.strip().split('\n')
                for container_id in container_ids:
                    if container_id:
                        log_info(f"Removing container {container_id} using port {port}")
                        self.runner.run(['docker', 'rm', '-f', container_id], check=False, capture_output=True)
                        
        except Exception as e:
            logger.debug(f"Error cleaning up port {port}: {e}")
    
    def get_registry_status(self) -> Dict[str, any]:
        """
        Get comprehensive registry status information.
        
        Returns:
            Dictionary with registry status information
        """
        name = self.config.registry_name
        port = self.config.registry_port
        
        return {
            'name': name,
            'port': port,
            'url': f'http://localhost:{port}',
            'running': self.is_registry_running(name),
            'healthy': self.is_registry_healthy(port),
            'docker_available': self.check_docker_available() if not self.dry_run else True
        }
    
    def list_registry_images(self, port: Optional[int] = None) -> List[str]:
        """
        List images in the registry.
        
        Args:
            port: Registry port (defaults to config value)
            
        Returns:
            List of image names in the registry
        """
        port = port or self.config.registry_port
        images = []
        
        try:
            # Get catalog of repositories
            result = self.runner.run([
                'curl', '-s',
                f'http://localhost:{port}/v2/_catalog'
            ], capture_output=True, check=False)
            
            if result.returncode == 0:
                import json
                catalog = json.loads(result.stdout)
                images = catalog.get('repositories', [])
                
        except Exception as e:
            logger.debug(f"Failed to list registry images: {e}")
        
        return images
