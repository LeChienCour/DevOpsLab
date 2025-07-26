#!/usr/bin/env python3
"""
Test runner for AWS DevOps Labs testing framework.
Runs unit tests, integration tests, and end-to-end tests with comprehensive reporting.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import unittest
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))


class TestRunner:
    """Comprehensive test runner for AWS DevOps Labs."""
    
    def __init__(self):
        """Initialize test runner."""
        self.test_dir = Path(__file__).parent
        self.base_dir = self.test_dir.parent
        self.results = {
            "start_time": None,
            "end_time": None,
            "duration": 0,
            "total_tests": 0,
            "passed_tests": 0,
            "failed_tests": 0,
            "skipped_tests": 0,
            "test_suites": {},
            "coverage": {},
            "errors": []
        }
    
    def run_all_tests(self, verbose: bool = False, coverage: bool = False) -> Dict:
        """Run all test suites."""
        print("🚀 Starting AWS DevOps Labs Test Suite")
        print("=" * 60)
        
        self.results["start_time"] = datetime.now().isoformat()
        start_time = time.time()
        
        # Define test suites
        test_suites = [
            ("Unit Tests", "test_lab_manager.py", "Tests core lab manager functionality"),
            ("CloudFormation Validation", "test_cloudformation_validation.py", "Tests CloudFormation template validation"),
            ("End-to-End Tests", "test_end_to_end.py", "Tests complete lab workflows")
        ]
        
        # Run each test suite
        for suite_name, test_file, description in test_suites:
            print(f"\n📋 Running {suite_name}")
            print(f"   {description}")
            print("-" * 40)
            
            suite_result = self._run_test_suite(test_file, verbose)
            self.results["test_suites"][suite_name] = suite_result
            
            # Update totals
            self.results["total_tests"] += suite_result["total"]
            self.results["passed_tests"] += suite_result["passed"]
            self.results["failed_tests"] += suite_result["failed"]
            self.results["skipped_tests"] += suite_result["skipped"]
            
            # Print suite summary
            status = "✅ PASSED" if suite_result["failed"] == 0 else "❌ FAILED"
            print(f"   {status} - {suite_result['passed']}/{suite_result['total']} tests passed")
            
            if suite_result["errors"]:
                print(f"   ⚠️  {len(suite_result['errors'])} errors encountered")
                for error in suite_result["errors"][:3]:  # Show first 3 errors
                    print(f"      • {error}")
                if len(suite_result["errors"]) > 3:
                    print(f"      ... and {len(suite_result['errors']) - 3} more errors")
        
        # Run coverage analysis if requested
        if coverage:
            print(f"\n📊 Running Coverage Analysis")
            print("-" * 40)
            coverage_result = self._run_coverage_analysis()
            self.results["coverage"] = coverage_result
        
        # Calculate final results
        end_time = time.time()
        self.results["end_time"] = datetime.now().isoformat()
        self.results["duration"] = round(end_time - start_time, 2)
        
        # Print final summary
        self._print_final_summary()
        
        return self.results
    
    def _run_test_suite(self, test_file: str, verbose: bool = False) -> Dict:
        """Run a specific test suite."""
        test_path = self.test_dir / test_file
        
        if not test_path.exists():
            return {
                "total": 0,
                "passed": 0,
                "failed": 1,
                "skipped": 0,
                "duration": 0,
                "errors": [f"Test file not found: {test_file}"]
            }
        
        # Run the test using unittest
        try:
            # Change to test directory for relative imports
            original_cwd = os.getcwd()
            os.chdir(self.test_dir)
            
            # Discover and run tests
            loader = unittest.TestLoader()
            suite = loader.loadTestsFromName(test_file[:-3])  # Remove .py extension
            
            # Create test runner with custom result class
            runner = unittest.TextTestRunner(
                verbosity=2 if verbose else 1,
                stream=sys.stdout,
                resultclass=DetailedTestResult
            )
            
            start_time = time.time()
            result = runner.run(suite)
            duration = round(time.time() - start_time, 2)
            
            # Extract results
            suite_result = {
                "total": result.testsRun,
                "passed": result.testsRun - len(result.failures) - len(result.errors) - len(result.skipped),
                "failed": len(result.failures) + len(result.errors),
                "skipped": len(result.skipped),
                "duration": duration,
                "errors": []
            }
            
            # Collect error messages
            for test, error in result.failures + result.errors:
                suite_result["errors"].append(f"{test}: {error.split('\\n')[0]}")
            
            return suite_result
            
        except Exception as e:
            return {
                "total": 0,
                "passed": 0,
                "failed": 1,
                "skipped": 0,
                "duration": 0,
                "errors": [f"Test execution error: {str(e)}"]
            }
        finally:
            os.chdir(original_cwd)
    
    def _run_coverage_analysis(self) -> Dict:
        """Run code coverage analysis."""
        try:
            # Try to import coverage
            import coverage
            
            # Create coverage instance
            cov = coverage.Coverage(source=[str(self.base_dir)])
            cov.start()
            
            # Run tests with coverage
            loader = unittest.TestLoader()
            suite = loader.discover(str(self.test_dir), pattern='test_*.py')
            runner = unittest.TextTestRunner(verbosity=0, stream=open(os.devnull, 'w'))
            runner.run(suite)
            
            cov.stop()
            cov.save()
            
            # Generate coverage report
            coverage_data = {}
            for filename in cov.get_data().measured_files():
                if filename.endswith('.py') and 'test' not in filename:
                    analysis = cov.analysis2(filename)
                    total_lines = len(analysis[1]) + len(analysis[2])
                    covered_lines = len(analysis[1])
                    coverage_percent = (covered_lines / total_lines * 100) if total_lines > 0 else 0
                    
                    coverage_data[Path(filename).name] = {
                        "covered_lines": covered_lines,
                        "total_lines": total_lines,
                        "coverage_percent": round(coverage_percent, 2)
                    }
            
            # Calculate overall coverage
            total_covered = sum(data["covered_lines"] for data in coverage_data.values())
            total_lines = sum(data["total_lines"] for data in coverage_data.values())
            overall_coverage = (total_covered / total_lines * 100) if total_lines > 0 else 0
            
            return {
                "overall_coverage": round(overall_coverage, 2),
                "files": coverage_data,
                "available": True
            }
            
        except ImportError:
            return {
                "overall_coverage": 0,
                "files": {},
                "available": False,
                "error": "Coverage package not installed. Install with: pip install coverage"
            }
        except Exception as e:
            return {
                "overall_coverage": 0,
                "files": {},
                "available": False,
                "error": f"Coverage analysis failed: {str(e)}"
            }
    
    def _print_final_summary(self):
        """Print final test summary."""
        print(f"\n🎯 Final Test Results")
        print("=" * 60)
        
        # Overall status
        overall_status = "✅ ALL TESTS PASSED" if self.results["failed_tests"] == 0 else "❌ SOME TESTS FAILED"
        print(f"Status: {overall_status}")
        print(f"Duration: {self.results['duration']} seconds")
        print()
        
        # Test statistics
        print("📈 Test Statistics:")
        print(f"   Total Tests: {self.results['total_tests']}")
        print(f"   Passed: {self.results['passed_tests']} ✅")
        print(f"   Failed: {self.results['failed_tests']} ❌")
        print(f"   Skipped: {self.results['skipped_tests']} ⏭️")
        
        if self.results["total_tests"] > 0:
            pass_rate = (self.results["passed_tests"] / self.results["total_tests"]) * 100
            print(f"   Pass Rate: {pass_rate:.1f}%")
        
        # Coverage information
        if self.results["coverage"].get("available"):
            print(f"\n📊 Code Coverage:")
            print(f"   Overall Coverage: {self.results['coverage']['overall_coverage']:.1f}%")
            
            # Show top covered files
            files = self.results["coverage"]["files"]
            if files:
                sorted_files = sorted(files.items(), key=lambda x: x[1]["coverage_percent"], reverse=True)
                print(f"   Top Covered Files:")
                for filename, data in sorted_files[:5]:
                    print(f"      {filename}: {data['coverage_percent']:.1f}%")
        elif "error" in self.results["coverage"]:
            print(f"\n📊 Code Coverage: {self.results['coverage']['error']}")
        
        # Suite breakdown
        print(f"\n📋 Test Suite Breakdown:")
        for suite_name, suite_result in self.results["test_suites"].items():
            status = "✅" if suite_result["failed"] == 0 else "❌"
            print(f"   {status} {suite_name}: {suite_result['passed']}/{suite_result['total']} passed ({suite_result['duration']}s)")
        
        print()
    
    def run_specific_test(self, test_name: str, verbose: bool = False) -> Dict:
        """Run a specific test or test class."""
        print(f"🎯 Running Specific Test: {test_name}")
        print("-" * 40)
        
        try:
            # Change to test directory
            original_cwd = os.getcwd()
            os.chdir(self.test_dir)
            
            # Load and run specific test
            loader = unittest.TestLoader()
            suite = loader.loadTestsFromName(test_name)
            
            runner = unittest.TextTestRunner(
                verbosity=2 if verbose else 1,
                resultclass=DetailedTestResult
            )
            
            start_time = time.time()
            result = runner.run(suite)
            duration = round(time.time() - start_time, 2)
            
            test_result = {
                "test_name": test_name,
                "total": result.testsRun,
                "passed": result.testsRun - len(result.failures) - len(result.errors),
                "failed": len(result.failures) + len(result.errors),
                "duration": duration,
                "success": len(result.failures) + len(result.errors) == 0
            }
            
            # Print summary
            status = "✅ PASSED" if test_result["success"] else "❌ FAILED"
            print(f"\n{status} - {test_result['passed']}/{test_result['total']} tests passed in {duration}s")
            
            return test_result
            
        except Exception as e:
            print(f"❌ Error running test: {str(e)}")
            return {
                "test_name": test_name,
                "total": 0,
                "passed": 0,
                "failed": 1,
                "duration": 0,
                "success": False,
                "error": str(e)
            }
        finally:
            os.chdir(original_cwd)
    
    def generate_report(self, output_file: Optional[str] = None) -> str:
        """Generate detailed test report."""
        if not output_file:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"test_report_{timestamp}.json"
        
        report_path = self.test_dir / output_file
        
        with open(report_path, 'w') as f:
            json.dump(self.results, f, indent=2, default=str)
        
        print(f"📄 Test report saved to: {report_path}")
        return str(report_path)


class DetailedTestResult(unittest.TextTestResult):
    """Custom test result class with detailed information."""
    
    def __init__(self, stream, descriptions, verbosity):
        super().__init__(stream, descriptions, verbosity)
        self.skipped = []
    
    def addSkip(self, test, reason):
        """Add skipped test."""
        super().addSkip(test, reason)
        self.skipped.append((test, reason))


def main():
    """Main entry point for test runner."""
    parser = argparse.ArgumentParser(description="AWS DevOps Labs Test Runner")
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Run tests with verbose output"
    )
    parser.add_argument(
        "--coverage", "-c",
        action="store_true",
        help="Run code coverage analysis"
    )
    parser.add_argument(
        "--test", "-t",
        type=str,
        help="Run specific test (e.g., test_lab_manager.TestLabManager.test_init)"
    )
    parser.add_argument(
        "--report", "-r",
        type=str,
        help="Generate test report to specified file"
    )
    parser.add_argument(
        "--suite", "-s",
        choices=["unit", "integration", "e2e", "all"],
        default="all",
        help="Run specific test suite"
    )
    
    args = parser.parse_args()
    
    runner = TestRunner()
    
    try:
        if args.test:
            # Run specific test
            result = runner.run_specific_test(args.test, args.verbose)
            success = result["success"]
        else:
            # Run test suite(s)
            if args.suite == "unit":
                # Run only unit tests
                result = runner._run_test_suite("test_lab_manager.py", args.verbose)
                success = result["failed"] == 0
            elif args.suite == "integration":
                # Run only integration tests
                result = runner._run_test_suite("test_cloudformation_validation.py", args.verbose)
                success = result["failed"] == 0
            elif args.suite == "e2e":
                # Run only end-to-end tests
                result = runner._run_test_suite("test_end_to_end.py", args.verbose)
                success = result["failed"] == 0
            else:
                # Run all tests
                results = runner.run_all_tests(args.verbose, args.coverage)
                success = results["failed_tests"] == 0
        
        # Generate report if requested
        if args.report:
            runner.generate_report(args.report)
        
        # Exit with appropriate code
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\n⚠️  Test execution interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"❌ Test runner error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()