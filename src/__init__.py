"""
OCM Demo Playground
==================

Main entry point for the OCM Demo Playground.
Converted from Bash scripts to Python for better error handling,
cross-platform compatibility, and maintainability.
"""

from .core.demo import DemoRunner
from .core.environment import EnvironmentManager
from .utils import setup_logging, get_config

__version__ = "2.0.0"
__all__ = ["DemoRunner", "EnvironmentManager", "setup_logging", "get_config"]
