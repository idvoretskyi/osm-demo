"""
OCM (Open Component Model) utilities for OCM Demo Playground.
Handles OCM CLI operations and component management.
"""

import json
import os
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Any

from .commands import CommandRunner, command_exists
from .config import get_config
from .logging import get_logger, log_error, log_info, log_success, log_warning

logger = get_logger('ocm')

class OCMClient:
    """Client for interacting with OCM CLI."""
    
    def __init__(self, dry_run: bool = False):
        """
        Initialize OCMClient.
        
        Args:
            dry_run: If True, commands will be logged but not executed
        """
        self.runner = CommandRunner(dry_run=dry_run)
        self.config = get_config()
        self.dry_run = dry_run
    
    def check_ocm_available(self) -> bool:
        """
        Check if OCM CLI is available.
        
        Returns:
            True if OCM CLI is available, False otherwise
        """
        if not command_exists('ocm'):
            log_error("OCM CLI not found", "Please run the setup script to install it")
            return False
        
        try:
            result = self.runner.run(['ocm', 'version'], capture_output=True, check=True)
            log_success(f"OCM CLI is available: {result.stdout.strip()}")
            return True
            
        except Exception as e:
            log_error(f"Failed to check OCM CLI: {e}")
            return False
    
    def get_version(self) -> Optional[str]:
        """
        Get OCM CLI version.
        
        Returns:
            OCM CLI version string or None if not available
        """
        try:
            result = self.runner.run(['ocm', 'version'], capture_output=True, check=True)
            return result.stdout.strip()
        except Exception:
            return None
    
    def create_component_version(
        self,
        component_spec: Dict[str, Any],
        output_dir: Optional[str] = None
    ) -> bool:
        """
        Create a component version from specification.
        
        Args:
            component_spec: Component specification dictionary
            output_dir: Output directory for the component archive
            
        Returns:
            True if component created successfully, False otherwise
        """
        if output_dir is None:
            output_dir = tempfile.mkdtemp(prefix='ocm_component_')
        
        spec_file = os.path.join(output_dir, 'component.yaml')
        
        try:
            # Write component specification to file
            try:
                import yaml
                with open(spec_file, 'w') as f:
                    yaml.dump(component_spec, f, default_flow_style=False)
            except ImportError:
                # Fallback: write component spec as JSON if yaml not available
                import json
                with open(spec_file.replace('.yaml', '.json'), 'w') as f:
                    json.dump(component_spec, f, indent=2)
                spec_file = spec_file.replace('.yaml', '.json')
            
            log_info(f"Creating component version from {spec_file}")
            
            # Create component version
            result = self.runner.run([
                'ocm', 'create', 'componentversion',
                '--file', spec_file,
                '--output', output_dir
            ], check=True)
            
            if result.returncode == 0:
                log_success("Component version created successfully")
                return True
            else:
                log_error("Failed to create component version")
                return False
                
        except Exception as e:
            log_error(f"Failed to create component version: {e}")
            return False
        finally:
            # Clean up temporary spec file
            if os.path.exists(spec_file):
                os.remove(spec_file)
    
    def transfer_component(
        self,
        source: str,
        target: str,
        component_ref: Optional[str] = None
    ) -> bool:
        """
        Transfer a component between repositories.
        
        Args:
            source: Source repository URL
            target: Target repository URL
            component_ref: Specific component reference (optional)
            
        Returns:
            True if transfer successful, False otherwise
        """
        cmd = ['ocm', 'transfer', 'component']
        
        if component_ref:
            cmd.extend([component_ref])
        
        cmd.extend([source, target])
        
        try:
            log_info(f"Transferring component from {source} to {target}")
            result = self.runner.run(cmd, check=True)
            
            if result.returncode == 0:
                log_success("Component transferred successfully")
                return True
            else:
                log_error("Failed to transfer component")
                return False
                
        except Exception as e:
            log_error(f"Failed to transfer component: {e}")
            return False
    
    def add_repository(self, name: str, url: str, repo_type: str = "oci") -> bool:
        """
        Add a repository to OCM configuration.
        
        Args:
            name: Repository alias name
            url: Repository URL
            repo_type: Repository type (default: oci)
            
        Returns:
            True if repository added successfully, False otherwise
        """
        try:
            log_info(f"Adding repository '{name}' -> {url}")
            result = self.runner.run([
                'ocm', 'add', 'repository',
                name, url,
                '--type', repo_type
            ], check=True)
            
            if result.returncode == 0:
                log_success(f"Repository '{name}' added successfully")
                return True
            else:
                log_error(f"Failed to add repository '{name}'")
                return False
                
        except Exception as e:
            log_error(f"Failed to add repository '{name}': {e}")
            return False
    
    def list_components(self, repository: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        List components in a repository.
        
        Args:
            repository: Repository name or URL (optional)
            
        Returns:
            List of component information dictionaries
        """
        cmd = ['ocm', 'get', 'components']
        if repository:
            cmd.append(repository)
        cmd.extend(['--output', 'json'])
        
        try:
            result = self.runner.run(cmd, capture_output=True, check=True)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
            else:
                log_warning("Failed to list components")
                return []
                
        except json.JSONDecodeError as e:
            log_error(f"Failed to parse component list JSON: {e}")
            return []
        except Exception as e:
            log_error(f"Failed to list components: {e}")
            return []
    
    def get_component_descriptor(self, component_ref: str) -> Optional[Dict[str, Any]]:
        """
        Get component descriptor for a component reference.
        
        Args:
            component_ref: Component reference
            
        Returns:
            Component descriptor dictionary or None if not found
        """
        try:
            result = self.runner.run([
                'ocm', 'get', 'component',
                component_ref,
                '--output', 'json'
            ], capture_output=True, check=True)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
            else:
                log_warning(f"Component not found: {component_ref}")
                return None
                
        except json.JSONDecodeError as e:
            log_error(f"Failed to parse component descriptor JSON: {e}")
            return None
        except Exception as e:
            log_error(f"Failed to get component descriptor: {e}")
            return None
    
    def sign_component(
        self,
        component_ref: str,
        private_key_file: str,
        signature_name: Optional[str] = None
    ) -> bool:
        """
        Sign a component with a private key.
        
        Args:
            component_ref: Component reference to sign
            private_key_file: Path to private key file
            signature_name: Name for the signature (optional)
            
        Returns:
            True if signing successful, False otherwise
        """
        cmd = ['ocm', 'sign', 'component', component_ref, '--private-key', private_key_file]
        
        if signature_name:
            cmd.extend(['--signature', signature_name])
        
        try:
            log_info(f"Signing component {component_ref}")
            result = self.runner.run(cmd, check=True)
            
            if result.returncode == 0:
                log_success("Component signed successfully")
                return True
            else:
                log_error("Failed to sign component")
                return False
                
        except Exception as e:
            log_error(f"Failed to sign component: {e}")
            return False
    
    def verify_component(
        self,
        component_ref: str,
        public_key_file: Optional[str] = None
    ) -> bool:
        """
        Verify a component signature.
        
        Args:
            component_ref: Component reference to verify
            public_key_file: Path to public key file (optional)
            
        Returns:
            True if verification successful, False otherwise
        """
        cmd = ['ocm', 'verify', 'component', component_ref]
        
        if public_key_file:
            cmd.extend(['--public-key', public_key_file])
        
        try:
            log_info(f"Verifying component {component_ref}")
            result = self.runner.run(cmd, check=True)
            
            if result.returncode == 0:
                log_success("Component verification successful")
                return True
            else:
                log_error("Component verification failed")
                return False
                
        except Exception as e:
            log_error(f"Failed to verify component: {e}")
            return False
    
    def download_resource(
        self,
        component_ref: str,
        resource_name: str,
        output_dir: str
    ) -> Optional[str]:
        """
        Download a resource from a component.
        
        Args:
            component_ref: Component reference
            resource_name: Name of the resource to download
            output_dir: Directory to save the resource
            
        Returns:
            Path to downloaded file or None if failed
        """
        try:
            os.makedirs(output_dir, exist_ok=True)
            
            log_info(f"Downloading resource '{resource_name}' from {component_ref}")
            result = self.runner.run([
                'ocm', 'download', 'resource',
                component_ref, resource_name,
                '--output-dir', output_dir
            ], check=True)
            
            if result.returncode == 0:
                # Find the downloaded file
                for file in os.listdir(output_dir):
                    file_path = os.path.join(output_dir, file)
                    if os.path.isfile(file_path):
                        log_success(f"Resource downloaded to: {file_path}")
                        return file_path
                
                log_warning("Resource downloaded but file not found")
                return None
            else:
                log_error("Failed to download resource")
                return None
                
        except Exception as e:
            log_error(f"Failed to download resource: {e}")
            return None
