"""
Logging utilities for OCM Demo Playground.
Provides colored console output and structured logging.
"""

import logging
import sys
from typing import Optional

# Try to import colorama, fallback to no colors if not available
try:
    from colorama import Fore, Style, init
    init(autoreset=True)
    COLORAMA_AVAILABLE = True
except ImportError:
    # Fallback when colorama is not available
    class _MockColor:
        def __getattr__(self, name):
            return ''
    
    Fore = Style = _MockColor()
    COLORAMA_AVAILABLE = False

class ColoredFormatter(logging.Formatter):
    """Custom formatter that adds colors to log messages."""
    
    COLORS = {
        'DEBUG': Fore.CYAN,
        'INFO': Fore.BLUE,
        'WARNING': Fore.YELLOW,
        'ERROR': Fore.RED,
        'CRITICAL': Fore.MAGENTA
    }
    
    ICONS = {
        'DEBUG': '🔍',
        'INFO': 'ℹ️ ',
        'WARNING': '⚠️ ',
        'ERROR': '❌',
        'CRITICAL': '💥'
    }
    
    def format(self, record):
        # Add color and icon to the levelname
        color = self.COLORS.get(record.levelname, '')
        icon = self.ICONS.get(record.levelname, '')
        
        # Create a copy of the record to avoid modifying the original
        colored_record = logging.makeLogRecord(record.__dict__)
        colored_record.levelname = f"{color}{icon} {record.levelname}{Style.RESET_ALL}"
        
        return super().format(colored_record)

def setup_logging(level: str = "INFO", format_string: Optional[str] = None) -> logging.Logger:
    """
    Set up logging with colored output.
    
    Args:
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        format_string: Custom format string for log messages
        
    Returns:
        Configured logger instance
    """
    if format_string is None:
        format_string = "%(levelname)s %(message)s"
    
    # Create logger
    logger = logging.getLogger('ocm_demo')
    logger.setLevel(getattr(logging, level.upper()))
    
    # Remove existing handlers to avoid duplicates
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, level.upper()))
    
    # Create formatter and add it to the handler
    formatter = ColoredFormatter(format_string)
    console_handler.setFormatter(formatter)
    
    # Add handler to logger
    logger.addHandler(console_handler)
    
    return logger

def get_logger(name: Optional[str] = None) -> logging.Logger:
    """
    Get a logger instance.
    
    Args:
        name: Logger name. If None, returns the main ocm_demo logger
        
    Returns:
        Logger instance
    """
    if name is None:
        return logging.getLogger('ocm_demo')
    return logging.getLogger(f'ocm_demo.{name}')

# Convenience functions that mirror the Bash script functions
def log_info(message: str):
    """Log an info message."""
    get_logger().info(message)

def log_success(message: str):
    """Log a success message."""
    logger = get_logger()
    logger.info(f"{Fore.GREEN}✅ {message}{Style.RESET_ALL}")

def log_warning(message: str):
    """Log a warning message."""
    get_logger().warning(message)

def log_error(message: str, hint: Optional[str] = None):
    """Log an error message with optional hint."""
    logger = get_logger()
    logger.error(message)
    if hint:
        logger.info(f"{Fore.YELLOW}💡 HINT: {hint}{Style.RESET_ALL}")

def log_step(message: str):
    """Log a step message."""
    logger = get_logger()
    logger.info(f"{Fore.CYAN}🔹 {message}{Style.RESET_ALL}")

def log_demo(message: str):
    """Log a demo message."""
    logger = get_logger()
    logger.info(f"{Fore.MAGENTA}🎬 {message}{Style.RESET_ALL}")
