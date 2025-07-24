#!/bin/bash

# Service Failure Simulation Script
# This script simulates service failures to test circuit breaker functionality

set -e

# Configuration
REGION=${AWS_DEFAULT_REGION:-us-east-1}
CLUSTER_NAME="cross-service-cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    echo "Usage: $0 <service-name> [action]"
    echo
    echo "Service names:"
    echo "  user-service"
    echo "  order-service"
    echo "  inventory-service"
    echo "  notification-service"
    echo
    echo "Actions:"
    echo "  fail      - Scale service to 0 tasks (simulate failure)"
    echo "  recover   - Scale service back to 2 tasks (simulate recovery)"
    echo "  status    - Show current service status"
    echo
    echo "Examples:"
    echo "  $0 user-service fail"
    echo "  $0 order-service recover"
    echo "  $0 inventory-service status"
    exit 1
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
}

# Function to get service ARN
get_service_arn() {
    local service_name=$1
    
    aws ecs list-services \
        --cluster "$CLUSTER_NAME" \
        --region "$REGION" \
        --query "serviceArns[?contains(@, '$service_name')]" \
        --output text
}

# Function to get current service status
get_service_status() {
    local service_name=$1
    local service_arn=$(get_service_arn "$service_name")
    
    if [ -z "$service_arn" ]; then
        echo "Service not found"
        return 1
    fi
    
    aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$service_arn" \
        --region "$REGION" \
        --query "services[0].{DesiredCount:desiredCount,RunningCount:runningCount,Status:status}" \
        --output table
}

# Function to scale service
scale_service() {
    local service_name=$1
    local desired_count=$2
    local service_arn=$(get_service_arn "$service_name")
    
    if [ -z "$service_arn" ]; then
        log_error "Service $service_name not found in cluster $CLUSTER_NAME"
        return 1
    fi
    
    log_info "Scaling $service_name to $desired_count tasks..."
    
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$service_arn" \
        --desired-count "$desired_count" \
        --region "$REGION" \
        --query "service.{ServiceName:serviceName,DesiredCount:desiredCount,Status:status}" \
        --output table
    
    log_success "Service $service_name scaled to $desired_count tasks"
}

# Function to simulate service failure
simulate_failure() {
    local service_name=$1
    
    log_warning "Simulating failure for $service_name..."
    scale_service "$service_name" 0
    
    echo
    log_info "Service failure simulation complete. The circuit breaker should detect this failure."
    log_info "You can monitor the circuit breaker state using:"
    echo "aws lambda invoke --function-name circuit-breaker-manager --payload '{\"service_name\": \"$service_name\", \"action\": \"check\"}' /tmp/response.json && cat /tmp/response.json"
}

# Function to simulate service recovery
simulate_recovery() {
    local service_name=$1
    
    log_info "Simulating recovery for $service_name..."
    scale_service "$service_name" 2
    
    echo
    log_success "Service recovery simulation complete. The circuit breaker should detect the recovery."
    log_info "You can monitor the circuit breaker state using:"
    echo "aws lambda invoke --function-name circuit-breaker-manager --payload '{\"service_name\": \"$service_name\", \"action\": \"check\"}' /tmp/response.json && cat /tmp/response.json"
}

# Function to show service status
show_status() {
    local service_name=$1
    
    log_info "Current status for $service_name:"
    get_service_status "$service_name"
    
    echo
    log_info "Circuit breaker state:"
    aws lambda invoke \
        --function-name circuit-breaker-manager \
        --payload "{\"service_name\": \"$service_name\", \"action\": \"check\"}" \
        --region "$REGION" \
        /tmp/cb_response.json > /dev/null 2>&1
    
    if [ -f /tmp/cb_response.json ]; then
        cat /tmp/cb_response.json | python3 -m json.tool 2>/dev/null || cat /tmp/cb_response.json
        rm -f /tmp/cb_response.json
    else
        log_warning "Could not retrieve circuit breaker state"
    fi
}

# Function to show all services status
show_all_status() {
    local services=("user-service" "order-service" "inventory-service" "notification-service")
    
    log_info "Status for all services:"
    echo
    
    for service in "${services[@]}"; do
        echo "=== $service ==="
        show_status "$service"
        echo
    done
}

# Function to test circuit breaker manually
test_circuit_breaker() {
    local service_name=$1
    
    log_info "Testing circuit breaker for $service_name..."
    
    # Record a few failures
    for i in {1..6}; do
        log_info "Recording failure $i/6..."
        aws lambda invoke \
            --function-name circuit-breaker-manager \
            --payload "{\"service_name\": \"$service_name\", \"action\": \"record\", \"success\": false}" \
            --region "$REGION" \
            /tmp/cb_test.json > /dev/null 2>&1
        
        if [ -f /tmp/cb_test.json ]; then
            cat /tmp/cb_test.json | python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"State: {json.loads(data['body'])['state']}, Failures: {json.loads(data['body'])['failure_count']}\")" 2>/dev/null || true
            rm -f /tmp/cb_test.json
        fi
        
        sleep 1
    done
    
    echo
    log_info "Circuit breaker should now be OPEN. Testing..."
    show_status "$service_name"
}

# Main function
main() {
    if [ $# -lt 1 ]; then
        usage
    fi
    
    local service_name=$1
    local action=${2:-status}
    
    # Validate service name
    case $service_name in
        user-service|order-service|inventory-service|notification-service)
            ;;
        all)
            if [ "$action" = "status" ]; then
                check_aws_cli
                show_all_status
                exit 0
            else
                log_error "Action '$action' not supported for 'all' services"
                exit 1
            fi
            ;;
        *)
            log_error "Invalid service name: $service_name"
            usage
            ;;
    esac
    
    # Check prerequisites
    check_aws_cli
    
    # Execute action
    case $action in
        fail)
            simulate_failure "$service_name"
            ;;
        recover)
            simulate_recovery "$service_name"
            ;;
        status)
            show_status "$service_name"
            ;;
        test-cb)
            test_circuit_breaker "$service_name"
            ;;
        *)
            log_error "Invalid action: $action"
            usage
            ;;
    esac
}

# Run main function
main "$@"