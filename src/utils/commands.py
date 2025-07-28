"""
Command execution utilities for OCM Demo Playground.
Provides cross-platform command execution with error handling.
"""

import shutil
import subprocess
import sys
from typing import Dict, List, Optional, Tuple, Union

from .logging import get_logger

logger = get_logger('commands')

def command_exists(command: str) -> bool:
    """
    Check if a command exists in the system PATH.
    
    Args:
        command: Command name to check
        
    Returns:
        True if command exists, False otherwise
    """
    return shutil.which(command) is not None

class CommandRunner:
    """Utility class for running shell commands with proper error handling."""
    
    def __init__(self, dry_run: bool = False):
        """
        Initialize CommandRunner.
        
        Args:
            dry_run: If True, commands will be logged but not executed
        """
        self.dry_run = dry_run
        self.logger = get_logger('commands')
    
    def run(
        self, 
        command: Union[str, List[str]], 
        cwd: Optional[str] = None,
        env: Optional[Dict[str, str]] = None,
        capture_output: bool = True,
        check: bool = True,
        shell: bool = None
    ) -> subprocess.CompletedProcess:
        """
        Run a command with proper error handling.
        
        Args:
            command: Command to run (string or list of arguments)
            cwd: Working directory for the command
            env: Environment variables
            capture_output: Whether to capture stdout/stderr
            check: Whether to raise exception on non-zero exit code
            shell: Whether to run in shell (auto-detected if None)
            
        Returns:
            CompletedProcess instance
            
        Raises:
            subprocess.CalledProcessError: If command fails and check=True
        """
        # Auto-detect shell usage
        if shell is None:
            shell = isinstance(command, str)
        
        # Convert command to string for logging
        cmd_str = command if isinstance(command, str) else ' '.join(command)
        
        if self.dry_run:
            self.logger.info(f"[DRY RUN] Would execute: {cmd_str}")
            return subprocess.CompletedProcess(
                args=command, 
                returncode=0, 
                stdout='', 
                stderr=''
            )
        
        self.logger.debug(f"Executing: {cmd_str}")
        if cwd:
            self.logger.debug(f"Working directory: {cwd}")
        
        try:
            result = subprocess.run(
                command,
                cwd=cwd,
                env=env,
                capture_output=capture_output,
                text=True,
                check=check,
                shell=shell
            )
            
            if result.returncode == 0:
                self.logger.debug(f"Command succeeded: {cmd_str}")
            else:
                self.logger.warning(f"Command returned non-zero exit code {result.returncode}: {cmd_str}")
                
            return result
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Command failed: {cmd_str}")
            self.logger.error(f"Exit code: {e.returncode}")
            if e.stdout:
                self.logger.error(f"STDOUT: {e.stdout}")
            if e.stderr:
                self.logger.error(f"STDERR: {e.stderr}")
            raise
        except FileNotFoundError as e:
            self.logger.error(f"Command not found: {cmd_str}")
            raise subprocess.CalledProcessError(127, command, None, str(e))
    
    def run_with_output(
        self, 
        command: Union[str, List[str]], 
        cwd: Optional[str] = None,
        env: Optional[Dict[str, str]] = None
    ) -> Tuple[int, str, str]:
        """
        Run a command and return exit code, stdout, and stderr.
        
        Args:
            command: Command to run
            cwd: Working directory
            env: Environment variables
            
        Returns:
            Tuple of (exit_code, stdout, stderr)
        """
        try:
            result = self.run(command, cwd=cwd, env=env, capture_output=True, check=False)
            return result.returncode, result.stdout, result.stderr
        except Exception as e:
            return 1, '', str(e)
    
    def check_prerequisites(self, commands: List[str]) -> Dict[str, bool]:
        """
        Check if multiple commands exist.
        
        Args:
            commands: List of command names to check
            
        Returns:
            Dictionary mapping command names to availability status
        """
        results = {}
        for cmd in commands:
            exists = command_exists(cmd)
            results[cmd] = exists
            if exists:
                self.logger.debug(f"✅ {cmd} is available")
            else:
                self.logger.warning(f"❌ {cmd} is not available")
        
        return results

def get_command_runner(dry_run: bool = False) -> CommandRunner:
    """
    Get a CommandRunner instance.
    
    Args:
        dry_run: Whether to run in dry-run mode
        
    Returns:
        CommandRunner instance
    """
    return CommandRunner(dry_run=dry_run)
