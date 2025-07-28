"""
Setup script for OCM Demo Playground.
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read the README file
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text(encoding="utf-8") if readme_file.exists() else ""

# Read requirements
requirements_file = Path(__file__).parent / "requirements.txt"
requirements = []
if requirements_file.exists():
    requirements = [
        line.strip()
        for line in requirements_file.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]

setup(
    name="ocm-demo-playground",
    version="2.0.0",
    description="Interactive demonstrations and examples for the Open Component Model (OCM)",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="OCM Community",
    author_email="ocm-dev@googlegroups.com",
    url="https://github.com/open-component-model/ocm-demo",
    packages=find_packages(),
    include_package_data=True,
    install_requires=requirements,
    python_requires=">=3.8",
    entry_points={
        "console_scripts": [
            "ocm-demo=src.cli.commands:main",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System :: Software Distribution",
    ],
    keywords="ocm, open-component-model, containers, kubernetes, supply-chain",
    project_urls={
        "Bug Reports": "https://github.com/open-component-model/ocm-demo/issues",
        "Source": "https://github.com/open-component-model/ocm-demo",
        "Documentation": "https://github.com/open-component-model/ocm-demo/docs",
    },
)
