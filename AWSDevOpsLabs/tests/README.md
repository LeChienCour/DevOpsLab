# AWS DevOps Labs Testing Framework

A comprehensive testing framework for AWS DevOps Professional certification lab exercises, providing automated testing for lab provisioning, CloudFormation template validation, and end-to-end lab execution workflows.

## 🎯 Overview

This testing framework ensures the reliability, security, and cost-effectiveness of AWS DevOps lab exercises through:

- **Unit Tests**: Core lab manager functionality and CLI commands
- **Integration Tests**: CloudFormation template validation and AWS service integration
- **End-to-End Tests**: Complete lab lifecycle from provisioning to cleanup
- **Security Testing**: Vulnerability scanning and compliance checks
- **Performance Testing**: Load testing and resource optimization
- **Cost Validation**: Budget tracking and Free Tier compliance

## 🚀 Quick Start

### Prerequisites

- Python 3.8+ installed
- AWS CLI configured (for integration tests)
- Git repository cloned

### Installation

1. **Set up virtual environment** (recommended):
```bash
cd AWSDevOpsLabs/tests
make setup-venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. **Install dependencies**:
```bash
make install
```

3. **Run all tests**:
```bash
make test-all
```

## 📋 Test Suites

### Unit Tests (`test_lab_manager.py`)
Tests core lab management functionality:
- Lab discovery and metadata parsing
- Session management and progress tracking
- Resource inventory and cost estimation
- CLI command validation

**Run unit tests:**
```bash
make test-unit
# or
python run_tests.py --suite unit
```

### Integration Tests (`test_cloudformation_validation.py`)
Tests CloudFormation template validation:
- Template syntax and parameter validation
- Resource dependency analysis
- Security best practices checking
- Cost estimation accuracy

**Run integration tests:**
```bash
make test-integration
# or
python run_tests.py --suite integration
```

### End-to-End Tests (`test_end_to_end.py`)
Tests complete lab workflows:
- Full lab lifecycle (start → progress → cleanup)
- Concurrent lab session management
- Resource provisioning and cleanup verification
- Error handling and recovery scenarios

**Run end-to-end tests:**
```bash
make test-e2e
# or
python run_tests.py --suite e2e
```

## 🔧 Usage Examples

### Running Specific Tests

```bash
# Run a specific test class
make test-specific TEST=test_lab_manager.TestLabManager

# Run a specific test method
make test-specific TEST=test_lab_manager.TestLabManager.test_start_lab

# Run tests with verbose output
python run_tests.py --verbose

# Run tests with coverage analysis
python run_tests.py --coverage
```

### Generating Reports

```bash
# Generate comprehensive test report
python run_tests.py --report test_report.json --coverage

# Generate coverage report
make coverage

# Generate all reports
make reports
```

### Code Quality Checks

```bash
# Run all quality checks
make full-check

# Individual quality checks
make lint          # Code style checking
make format        # Code formatting
make security      # Security scanning
make validate-templates  # CloudFormation validation
```

## 📊 Test Configuration

### Configuration File (`test_config.yaml`)

The testing framework uses a comprehensive configuration file that defines:

- **Test Environment Settings**: AWS regions, timeouts, concurrency limits
- **Mock AWS Responses**: Predefined responses for offline testing
- **Validation Rules**: CloudFormation security checks, resource limits
- **Reporting Configuration**: Output formats, coverage thresholds
- **CI/CD Settings**: Parallel execution, retry policies

### Key Configuration Sections

```yaml
# Test environment
environment:
  aws_region: "us-east-1"
  test_timeout: 300
  max_concurrent_tests: 3

# Validation rules
validation:
  cloudformation:
    required_tags: ["Project", "SessionId", "LabName"]
    security_checks: true
    cost_limits:
      max_hourly_cost: 10.0

# Resource limits
resource_limits:
  max_ec2_instances: 5
  allowed_instance_types: ["t3.micro", "t3.small"]
```

## 🛠️ Development Workflow

### Adding New Tests

1. **Create test file** following naming convention `test_*.py`
2. **Inherit from appropriate base class**:
   - `unittest.TestCase` for unit tests
   - Custom base classes for integration/e2e tests
3. **Use descriptive test names** and docstrings
4. **Mock AWS services** for unit tests
5. **Add test to appropriate suite** in `run_tests.py`

### Test Structure Example

```python
class TestNewFeature(unittest.TestCase):
    """Test cases for new feature functionality."""
    
    def setUp(self):
        """Set up test environment."""
        # Initialize test data and mocks
        pass
    
    def test_feature_functionality(self):
        """Test specific feature functionality."""
        # Arrange
        # Act
        # Assert
        pass
    
    def tearDown(self):
        """Clean up test environment."""
        # Clean up resources
        pass
```

### Mocking AWS Services

```python
from unittest.mock import Mock, patch

@patch('boto3.client')
def test_aws_integration(self, mock_boto_client):
    """Test AWS service integration."""
    # Mock AWS client
    mock_client = Mock()
    mock_boto_client.return_value = mock_client
    
    # Configure mock responses
    mock_client.describe_stacks.return_value = {
        'Stacks': [{'StackName': 'test-stack'}]
    }
    
    # Test functionality
    result = your_function_that_uses_aws()
    
    # Verify interactions
    mock_client.describe_stacks.assert_called_once()
```

## 🔍 Debugging and Troubleshooting

### Debug Mode

```bash
# Run tests in debug mode
make debug

# Profile test execution
make profile
```

### Common Issues

1. **AWS Credentials Not Configured**
   - Solution: Configure AWS CLI or set environment variables
   - Tests use mocked AWS services by default

2. **Test Timeouts**
   - Solution: Increase timeout in `test_config.yaml`
   - Check for infinite loops or blocking operations

3. **Import Errors**
   - Solution: Ensure virtual environment is activated
   - Install dependencies with `make install`

4. **CloudFormation Validation Failures**
   - Solution: Check template syntax with `cfn-lint`
   - Verify required parameters and resources

### Logging and Diagnostics

```python
import logging

# Enable debug logging in tests
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

def test_with_logging(self):
    logger.debug("Starting test execution")
    # Test code here
    logger.info("Test completed successfully")
```

## 📈 Continuous Integration

### GitHub Actions Workflow

The framework includes a comprehensive CI/CD pipeline (`.github/workflows/test.yml`) that:

- Runs on push/PR to main branches
- Tests multiple Python versions (3.8-3.11)
- Performs code quality checks
- Generates coverage reports
- Uploads test artifacts
- Provides test summaries

### CI Commands

```bash
# Setup CI environment
make ci-setup

# Run CI test suite
make ci-test

# Run CI quality checks
make ci-quality
```

### Local CI Simulation

```bash
# Run the same checks as CI
make full-check
```

## 📊 Coverage and Reporting

### Coverage Analysis

```bash
# Generate HTML coverage report
make coverage

# Generate XML coverage report (for CI)
make coverage-xml

# View coverage in browser
open coverage_html/index.html
```

### Test Reports

The framework generates multiple report formats:

- **JSON Reports**: Machine-readable test results
- **HTML Reports**: Human-readable test summaries
- **JUnit XML**: CI/CD integration format
- **Coverage Reports**: Code coverage analysis

### Report Locations

```
tests/
├── reports/
│   ├── test_report.json
│   ├── coverage_report.json
│   └── security_report.json
├── coverage_html/
│   └── index.html
└── junit_results.xml
```

## 🔒 Security Testing

### Security Checks

```bash
# Run security scanning
make security

# Individual security tools
bandit -r .           # Python security linter
safety check          # Dependency vulnerability scanner
```

### Security Configuration

Security testing includes:

- **Static Analysis**: Code vulnerability scanning
- **Dependency Scanning**: Known vulnerability detection
- **CloudFormation Security**: Template security validation
- **Compliance Checks**: AWS Config rules validation

## 🚀 Performance Testing

### Load Testing

```bash
# Run performance tests
make perf-test
```

### Performance Metrics

The framework tracks:

- Test execution time
- Resource provisioning time
- Memory usage
- AWS API call patterns
- Cost per test execution

## 📚 Best Practices

### Test Writing Guidelines

1. **Follow AAA Pattern**: Arrange, Act, Assert
2. **Use Descriptive Names**: Test names should explain what is being tested
3. **Keep Tests Independent**: Each test should be able to run in isolation
4. **Mock External Dependencies**: Use mocks for AWS services and external APIs
5. **Test Edge Cases**: Include error conditions and boundary values
6. **Maintain Test Data**: Use fixtures and factories for consistent test data

### Performance Guidelines

1. **Minimize AWS Calls**: Use mocks for unit tests
2. **Parallel Execution**: Run independent tests concurrently
3. **Resource Cleanup**: Always clean up test resources
4. **Timeout Handling**: Set appropriate timeouts for long-running tests

### Security Guidelines

1. **No Hardcoded Secrets**: Use environment variables or mocks
2. **Least Privilege**: Test with minimal required permissions
3. **Secure Test Data**: Don't use production data in tests
4. **Vulnerability Scanning**: Regularly scan dependencies

## 🤝 Contributing

### Adding New Tests

1. Fork the repository
2. Create a feature branch
3. Add tests following the established patterns
4. Run the full test suite
5. Submit a pull request

### Test Review Checklist

- [ ] Tests follow naming conventions
- [ ] All tests pass locally
- [ ] Code coverage maintained or improved
- [ ] Security checks pass
- [ ] Documentation updated
- [ ] CI/CD pipeline passes

## 📞 Support

### Getting Help

1. **Check Documentation**: Review this README and inline comments
2. **Run Diagnostics**: Use debug mode and logging
3. **Check Issues**: Look for similar issues in the repository
4. **Create Issue**: Submit detailed bug reports or feature requests

### Useful Commands

```bash
# Show all available make targets
make help

# Show test execution examples
make test-help

# Quick health check
make quick-test
```

## 📄 License

This testing framework is part of the AWS DevOps Labs project and follows the same licensing terms.

---

**Happy Testing! 🧪✨**