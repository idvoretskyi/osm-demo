#!/usr/bin/env python3
"""
Main entry point for OCM Demo Playground.
"""

import sys
from pathlib import Path

# Add the src directory to Python path
src_dir = Path(__file__).parent / "src"
sys.path.insert(0, str(src_dir))

from cli.commands import main

if __name__ == '__main__':
    sys.exit(main())
