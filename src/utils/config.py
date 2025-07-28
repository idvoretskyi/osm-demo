"""
Configuration management for OCM Demo Playground.
Handles default values and environment variable overrides.
"""

import os
from dataclasses import dataclass
from typing import Optional

@dataclass
class Config:
    """Configuration class for OCM Demo Playground."""
    
    # Registry configuration
    registry_port: int = 5001
    registry_name: str = "local-registry"
    registry_host: str = "localhost"
    
    # Cluster configuration
    cluster_name: str = "ocm-demo"
    namespace: str = "ocm-demos"
    
    # Demo configuration
    demo_duration: int = 300  # 5 minutes
    
    # Paths
    project_root: Optional[str] = None
    
    @classmethod
    def from_environment(cls) -> 'Config':
        """
        Create configuration from environment variables.
        
        Environment variables:
        - OCM_DEMO_REGISTRY_PORT: Registry port (default: 5001)
        - OCM_DEMO_REGISTRY_NAME: Registry name (default: local-registry)
        - OCM_DEMO_CLUSTER_NAME: Cluster name (default: ocm-demo)
        - OCM_DEMO_NAMESPACE: Kubernetes namespace (default: ocm-demos)
        
        Returns:
            Config instance with values from environment
        """
        return cls(
            registry_port=int(os.getenv('OCM_DEMO_REGISTRY_PORT', '5001')),
            registry_name=os.getenv('OCM_DEMO_REGISTRY_NAME', 'local-registry'),
            registry_host=os.getenv('OCM_DEMO_REGISTRY_HOST', 'localhost'),
            cluster_name=os.getenv('OCM_DEMO_CLUSTER_NAME', 'ocm-demo'),
            namespace=os.getenv('OCM_DEMO_NAMESPACE', 'ocm-demos'),
            demo_duration=int(os.getenv('OCM_DEMO_DURATION', '300')),
            project_root=os.getenv('OCM_DEMO_PROJECT_ROOT')
        )
    
    @property
    def registry_url(self) -> str:
        """Get the complete registry URL."""
        return f"{self.registry_host}:{self.registry_port}"
    
    def to_dict(self) -> dict:
        """Convert config to dictionary."""
        return {
            'registry_port': self.registry_port,
            'registry_name': self.registry_name,
            'registry_host': self.registry_host,
            'cluster_name': self.cluster_name,
            'namespace': self.namespace,
            'demo_duration': self.demo_duration,
            'project_root': self.project_root,
            'registry_url': self.registry_url
        }

# Global config instance
_config: Optional[Config] = None

def get_config() -> Config:
    """
    Get the global configuration instance.
    
    Returns:
        Config instance loaded from environment
    """
    global _config
    if _config is None:
        _config = Config.from_environment()
    return _config

def set_config(config: Config) -> None:
    """
    Set the global configuration instance.
    
    Args:
        config: Config instance to set as global
    """
    global _config
    _config = config
