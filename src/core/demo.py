"""
Demo runner for OCM Demo Playground.
Orchestrates the demo workflow and examples.
Converts functionality from quick-demo.sh and test-all.sh
"""

import time
from pathlib import Path
from typing import Dict, List, Optional

from ..utils.config import get_config
from ..utils.logging import get_logger, log_demo, log_error, log_info, log_step, log_success
from .environment import EnvironmentManager

logger = get_logger('demo')

class DemoRunner:
    """Manages and executes OCM demo scenarios."""
    
    def __init__(self, dry_run: bool = False):
        """
        Initialize DemoRunner.
        
        Args:
            dry_run: If True, commands will be logged but not executed
        """
        self.config = get_config()
        self.environment = EnvironmentManager(dry_run=dry_run)
        self.dry_run = dry_run
        self.examples_dir = Path(__file__).parent.parent.parent / "examples"
    
    def run_quick_demo(self, interactive: bool = True) -> bool:
        """
        Run the 5-minute quick demo tour.
        
        Args:
            interactive: Whether to run in interactive mode with pauses
            
        Returns:
            True if demo completed successfully, False otherwise
        """
        self._print_demo_header()
        
        if not self._check_environment():
            return False
        
        log_demo("Starting OCM Demo Tour - showcasing key capabilities")
        
        demo_steps = [
            ("Basic Component Creation", self._demo_basic_components),
            ("Component Transport", self._demo_transport),
            ("Component Signing", self._demo_signing),
            ("Kubernetes Deployment", self._demo_k8s_deployment),
            ("Advanced Features", self._demo_advanced_features)
        ]
        
        success = True
        
        for i, (step_name, step_func) in enumerate(demo_steps, 1):
            log_step(f"Step {i}/5: {step_name}")
            
            try:
                if not step_func():
                    log_error(f"Step {i} failed: {step_name}")
                    success = False
                    break
                
                if interactive and i < len(demo_steps):
                    self._interactive_pause(f"Step {i} complete. Press Enter to continue to Step {i+1}...")
                
            except KeyboardInterrupt:
                log_info("Demo interrupted by user")
                return False
            except Exception as e:
                log_error(f"Step {i} failed with exception: {e}")
                success = False
                break
        
        if success:
            self._print_demo_footer()
        
        return success
    
    def run_all_tests(self) -> bool:
        """
        Run comprehensive test suite covering all examples.
        
        Returns:
            True if all tests passed, False otherwise
        """
        log_info("Running comprehensive OCM demo test suite...")
        
        if not self._check_environment():
            return False
        
        test_results = {}
        
        # Test each example directory
        example_dirs = [
            "01-basic",
            "02-transport", 
            "03-signing",
            "04-k8s-deployment",
            "05-advanced"
        ]
        
        for example_dir in example_dirs:
            log_info(f"Testing {example_dir}...")
            result = self._run_example_tests(example_dir)
            test_results[example_dir] = result
            
            if result:
                log_success(f"✅ {example_dir} tests passed")
            else:
                log_error(f"❌ {example_dir} tests failed")
        
        # Summary
        passed = sum(1 for result in test_results.values() if result)
        total = len(test_results)
        
        log_info(f"Test Results: {passed}/{total} example sets passed")
        
        if passed == total:
            log_success("🎉 All tests passed!")
            return True
        else:
            log_error(f"❌ {total - passed} test sets failed")
            return False
    
    def run_specific_example(self, example_name: str) -> bool:
        """
        Run a specific example by name.
        
        Args:
            example_name: Name of the example to run
            
        Returns:
            True if example ran successfully, False otherwise
        """
        log_info(f"Running example: {example_name}")
        
        if not self._check_environment():
            return False
        
        example_path = self.examples_dir / example_name
        if not example_path.exists():
            log_error(f"Example not found: {example_name}")
            return False
        
        return self._run_example_tests(example_name)
    
    def list_available_examples(self) -> List[str]:
        """
        List all available examples.
        
        Returns:
            List of example directory names
        """
        examples = []
        if self.examples_dir.exists():
            for item in self.examples_dir.iterdir():
                if item.is_dir() and not item.name.startswith('.'):
                    examples.append(item.name)
        
        return sorted(examples)
    
    def _check_environment(self) -> bool:
        """Check if environment is ready for demo."""
        status = self.environment.get_environment_status()
        
        if not status['ready']:
            log_error("Environment not ready for demo")
            
            missing = [tool for tool, available in status['prerequisites'].items() if not available]
            if missing:
                log_error(f"Missing prerequisites: {', '.join(missing)}")
            
            if not status['registry']['running']:
                log_error("Local registry not running")
            
            log_info("Please run the setup script first: python -m src.cli setup")
            return False
        
        return True
    
    def _demo_basic_components(self) -> bool:
        """Demo basic component creation (Step 1)."""
        log_demo("Creating a simple 'Hello World' component...")
        
        # Run the basic hello-world example
        return self._run_example_script("01-basic/hello-world", "create-component.sh")
    
    def _demo_transport(self) -> bool:
        """Demo component transport (Step 2)."""
        log_demo("Transporting components between repositories...")
        
        # Run transport examples
        return self._run_example_script("02-transport/local-to-oci", "transport-example.sh")
    
    def _demo_signing(self) -> bool:
        """Demo component signing (Step 3)."""
        log_demo("Signing components for security and authenticity...")
        
        # Run signing examples
        return self._run_example_script("03-signing/basic-signing", "sign-component.sh")
    
    def _demo_k8s_deployment(self) -> bool:
        """Demo Kubernetes deployment (Step 4)."""
        log_demo("Deploying components to Kubernetes...")
        
        # Set up cluster and deploy
        success = self._run_example_script("04-k8s-deployment", "setup-cluster.sh")
        if success:
            success = self._run_example_script("04-k8s-deployment/ocm-k8s-toolkit", "deploy-example.sh")
        
        return success
    
    def _demo_advanced_features(self) -> bool:
        """Demo advanced features (Step 5)."""
        log_demo("Showcasing advanced OCM features...")
        
        # Run advanced examples
        success = self._run_example_script("05-advanced/component-references", "create-reference-example.sh")
        if success:
            success = self._run_example_script("05-advanced/localization", "create-localization-example.sh")
        
        return success
    
    def _run_example_tests(self, example_dir: str) -> bool:
        """
        Run tests for a specific example directory.
        
        Args:
            example_dir: Name of the example directory
            
        Returns:
            True if tests passed, False otherwise
        """
        example_path = self.examples_dir / example_dir
        run_script = example_path / "run-examples.sh"
        
        if run_script.exists():
            return self._run_bash_script(str(run_script))
        else:
            # Look for individual example scripts
            success = True
            for subdir in example_path.iterdir():
                if subdir.is_dir():
                    script_files = list(subdir.glob("*.sh"))
                    for script in script_files:
                        if not self._run_bash_script(str(script)):
                            success = False
            return success
    
    def _run_example_script(self, relative_path: str, script_name: str) -> bool:
        """
        Run a specific example script.
        
        Args:
            relative_path: Path relative to examples directory
            script_name: Name of the script file
            
        Returns:
            True if script succeeded, False otherwise
        """
        script_path = self.examples_dir / relative_path / script_name
        
        if not script_path.exists():
            log_error(f"Script not found: {script_path}")
            return False
        
        return self._run_bash_script(str(script_path))
    
    def _run_bash_script(self, script_path: str) -> bool:
        """
        Run a bash script with proper error handling.
        
        Args:
            script_path: Path to the bash script
            
        Returns:
            True if script succeeded, False otherwise
        """
        if self.dry_run:
            log_info(f"[DRY RUN] Would execute: {script_path}")
            return True
        
        try:
            from ..utils.commands import get_command_runner
            runner = get_command_runner()
            
            # Make script executable
            runner.run(['chmod', '+x', script_path], check=False)
            
            # Run the script
            result = runner.run(['bash', script_path], check=False)
            
            return result.returncode == 0
            
        except Exception as e:
            log_error(f"Failed to run script {script_path}: {e}")
            return False
    
    def _interactive_pause(self, message: str):
        """
        Pause for user input in interactive mode.
        
        Args:
            message: Message to display to user
        """
        if not self.dry_run:
            input(f"\n{message}")
        log_info(message)
    
    def _print_demo_header(self):
        """Print the demo header."""
        print("\n" + "="*80)
        print("                        OCM Demo Playground")
        print("                         Quick Demo Tour")
        print("")
        print("  This 5-minute demo showcases the key features of the Open Component Model")
        print("="*80 + "\n")
    
    def _print_demo_footer(self):
        """Print the demo footer."""
        print("\n" + "="*80)
        print("                            Demo Complete!")
        print("")
        print("  🎉 You've seen the key OCM capabilities in action!")
        print("")
        print("  Next steps:")
        print("  • Explore individual examples in examples/")
        print("  • Read the documentation in docs/")
        print("  • Try the comprehensive test suite: python -m src.cli test")
        print("="*80 + "\n")
    
    def get_demo_status(self) -> Dict[str, any]:
        """
        Get demo environment status.
        
        Returns:
            Dictionary with demo status information
        """
        env_status = self.environment.get_environment_status()
        examples = self.list_available_examples()
        
        return {
            'environment': env_status,
            'available_examples': examples,
            'examples_count': len(examples),
            'ready_for_demo': env_status['ready']
        }
