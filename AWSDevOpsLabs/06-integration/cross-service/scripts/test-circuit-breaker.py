#!/usr/bin/env python3

"""
Circuit Breaker Testing Script
This script tests the circuit breaker functionality by simulating service calls
and monitoring state changes.
"""

import json
import time
import boto3
import requests
import argparse
from typing import Dict, Any
import sys

class CircuitBreakerTester:
    def __init__(self, region: str = 'us-east-1'):
        self.lambda_client = boto3.client('lambda', region_name=region)
        self.circuit_breaker_function = 'circuit-breaker-manager'
        
    def call_circuit_breaker(self, service_name: str, action: str, success: bool = None) -> Dict[str, Any]:
        """Call the circuit breaker Lambda function"""
        payload = {
            'service_name': service_name,
            'action': action
        }
        
        if success is not None:
            payload['success'] = success
            
        try:
            response = self.lambda_client.invoke(
                FunctionName=self.circuit_breaker_function,
                InvocationType='RequestResponse',
                Payload=json.dumps(payload)
            )
            
            result = json.loads(response['Payload'].read())
            if 'body' in result:
                return json.loads(result['body'])
            return result
            
        except Exception as e:
            print(f"Error calling circuit breaker: {e}")
            return {'error': str(e)}
    
    def check_circuit_state(self, service_name: str) -> Dict[str, Any]:
        """Check the current circuit breaker state"""
        return self.call_circuit_breaker(service_name, 'check')
    
    def record_success(self, service_name: str) -> Dict[str, Any]:
        """Record a successful service call"""
        return self.call_circuit_breaker(service_name, 'record', True)
    
    def record_failure(self, service_name: str) -> Dict[str, Any]:
        """Record a failed service call"""
        return self.call_circuit_breaker(service_name, 'record', False)
    
    def reset_circuit(self, service_name: str) -> Dict[str, Any]:
        """Reset the circuit breaker to CLOSED state"""
        return self.call_circuit_breaker(service_name, 'reset')
    
    def test_circuit_breaker_flow(self, service_name: str):
        """Test the complete circuit breaker flow"""
        print(f"Testing circuit breaker for service: {service_name}")
        print("=" * 50)
        
        # Reset circuit breaker to start fresh
        print("1. Resetting circuit breaker...")
        reset_result = self.reset_circuit(service_name)
        print(f"   Reset result: {reset_result}")
        
        # Check initial state
        print("\n2. Checking initial state...")
        state = self.check_circuit_state(service_name)
        print(f"   Initial state: {state}")
        
        # Record some successful calls
        print("\n3. Recording successful calls...")
        for i in range(3):
            result = self.record_success(service_name)
            print(f"   Success {i+1}: State={result.get('state')}, Success Count={result.get('success_count')}")
            time.sleep(0.5)
        
        # Record failures to trigger circuit breaker
        print("\n4. Recording failures to trigger circuit breaker...")
        failure_threshold = 5
        for i in range(failure_threshold + 1):
            result = self.record_failure(service_name)
            state = result.get('state')
            failure_count = result.get('failure_count')
            print(f"   Failure {i+1}: State={state}, Failure Count={failure_count}")
            
            if state == 'OPEN':
                print(f"   🔴 Circuit breaker OPENED after {i+1} failures!")
                break
            time.sleep(0.5)
        
        # Try to make a call when circuit is open
        print("\n5. Checking if requests are blocked when circuit is OPEN...")
        state = self.check_circuit_state(service_name)
        allow_request = state.get('allow_request', True)
        print(f"   Circuit state: {state.get('state')}")
        print(f"   Allow request: {allow_request}")
        
        if not allow_request:
            print("   ✅ Circuit breaker is correctly blocking requests!")
        else:
            print("   ❌ Circuit breaker should be blocking requests!")
        
        # Wait for timeout and test half-open state
        print("\n6. Waiting for circuit breaker timeout (60 seconds)...")
        print("   This will test the transition to HALF_OPEN state...")
        
        for remaining in range(60, 0, -5):
            print(f"   Waiting... {remaining} seconds remaining")
            time.sleep(5)
        
        # Check if circuit moved to half-open
        print("\n7. Checking if circuit moved to HALF_OPEN...")
        state = self.check_circuit_state(service_name)
        print(f"   Current state: {state}")
        
        # Record successful calls to close the circuit
        print("\n8. Recording successful calls to close the circuit...")
        success_threshold = 3
        for i in range(success_threshold):
            result = self.record_success(service_name)
            state = result.get('state')
            success_count = result.get('success_count')
            print(f"   Success {i+1}: State={state}, Success Count={success_count}")
            
            if state == 'CLOSED':
                print(f"   🟢 Circuit breaker CLOSED after {i+1} successes!")
                break
            time.sleep(0.5)
        
        # Final state check
        print("\n9. Final state check...")
        final_state = self.check_circuit_state(service_name)
        print(f"   Final state: {final_state}")
        
        print("\n" + "=" * 50)
        print("Circuit breaker test completed!")
    
    def monitor_circuit_breaker(self, service_name: str, duration: int = 300):
        """Monitor circuit breaker state changes over time"""
        print(f"Monitoring circuit breaker for {service_name} for {duration} seconds...")
        print("Press Ctrl+C to stop monitoring")
        
        start_time = time.time()
        last_state = None
        
        try:
            while time.time() - start_time < duration:
                state = self.check_circuit_state(service_name)
                current_state = state.get('state')
                
                if current_state != last_state:
                    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
                    print(f"[{timestamp}] State changed to: {current_state}")
                    print(f"   Details: {state}")
                    last_state = current_state
                
                time.sleep(5)
                
        except KeyboardInterrupt:
            print("\nMonitoring stopped by user")
    
    def simulate_load_test(self, service_name: str, success_rate: float = 0.7, duration: int = 120):
        """Simulate load testing with configurable success rate"""
        print(f"Simulating load test for {service_name}")
        print(f"Success rate: {success_rate * 100}%")
        print(f"Duration: {duration} seconds")
        print("Press Ctrl+C to stop")
        
        start_time = time.time()
        call_count = 0
        success_count = 0
        failure_count = 0
        
        try:
            while time.time() - start_time < duration:
                call_count += 1
                
                # Simulate success/failure based on success rate
                import random
                is_success = random.random() < success_rate
                
                if is_success:
                    result = self.record_success(service_name)
                    success_count += 1
                else:
                    result = self.record_failure(service_name)
                    failure_count += 1
                
                state = result.get('state')
                
                if call_count % 10 == 0:
                    print(f"Calls: {call_count}, Successes: {success_count}, "
                          f"Failures: {failure_count}, Circuit: {state}")
                
                time.sleep(0.5)
                
        except KeyboardInterrupt:
            print("\nLoad test stopped by user")
        
        print(f"\nLoad test summary:")
        print(f"Total calls: {call_count}")
        print(f"Successes: {success_count}")
        print(f"Failures: {failure_count}")
        print(f"Success rate: {success_count/call_count*100:.1f}%")

def main():
    parser = argparse.ArgumentParser(description='Circuit Breaker Testing Tool')
    parser.add_argument('service_name', help='Service name to test')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--action', choices=['test', 'monitor', 'load-test', 'check', 'reset'], 
                       default='test', help='Action to perform')
    parser.add_argument('--duration', type=int, default=300, 
                       help='Duration for monitoring or load testing (seconds)')
    parser.add_argument('--success-rate', type=float, default=0.7,
                       help='Success rate for load testing (0.0-1.0)')
    
    args = parser.parse_args()
    
    tester = CircuitBreakerTester(args.region)
    
    try:
        if args.action == 'test':
            tester.test_circuit_breaker_flow(args.service_name)
        elif args.action == 'monitor':
            tester.monitor_circuit_breaker(args.service_name, args.duration)
        elif args.action == 'load-test':
            tester.simulate_load_test(args.service_name, args.success_rate, args.duration)
        elif args.action == 'check':
            state = tester.check_circuit_state(args.service_name)
            print(json.dumps(state, indent=2))
        elif args.action == 'reset':
            result = tester.reset_circuit(args.service_name)
            print(json.dumps(result, indent=2))
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()