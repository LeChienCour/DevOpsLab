#!/usr/bin/env python3
"""
Simple AWS Pricing Helper

A lightweight pricing analysis helper that provides basic cost estimation
and Free Tier tracking without the complexity of multiple modules.
"""

import json
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import logging

try:
    import boto3
    from botocore.exceptions import ClientError, NoCredentialsError
    AWS_AVAILABLE = True
except ImportError:
    AWS_AVAILABLE = False

logger = logging.getLogger(__name__)

class SimplePricingHelper:
    """Simple pricing helper for AWS DevOps Labs"""
    
    # Basic Free Tier limits (monthly)
    FREE_TIER_LIMITS = {
        'EC2': 750,      # hours of t2.micro/t3.micro
        'S3': 5,         # GB storage
        'Lambda': 1000000,  # requests
        'CodeBuild': 100    # build minutes
    }
    
    # Fallback pricing (USD per hour/unit)
    FALLBACK_PRICING = {
        'EC2': 0.0104,      # t3.micro per hour
        'S3': 0.023,        # per GB per month
        'Lambda': 0.0000002, # per request
        'CodeBuild': 0.005,  # per build minute
        'RDS': 0.017,       # db.t3.micro per hour
        'CloudWatch': 0.30   # basic monitoring
    }
    
    def __init__(self):
        """Initialize the pricing helper"""
        self.aws_available = AWS_AVAILABLE
        self.pricing_client = None
        
        if self.aws_available:
            try:
                self.pricing_client = boto3.client('pricing', region_name='us-east-1')
                logger.info("AWS pricing client initialized")
            except Exception as e:
                logger.warning(f"Could not initialize AWS pricing client: {e}")
                self.aws_available = False
    
    def estimate_lab_cost(self, services: List[str], duration_hours: float) -> Dict:
        """
        Estimate lab cost with Free Tier consideration
        
        Args:
            services: List of AWS services used
            duration_hours: Lab duration in hours
            
        Returns:
            Dictionary with cost estimation
        """
        result = {
            'duration_hours': duration_hours,
            'services': services,
            'free_tier_cost': 0.0,
            'standard_cost': 0.0,
            'potential_savings': 0.0,
            'free_tier_eligible': True,
            'breakdown': {}
        }
        
        for service in services:
            service_upper = service.upper()
            
            if service_upper == 'EC2':
                # Assume t3.micro instance
                hours_used = duration_hours
                free_tier_hours = min(hours_used, self.FREE_TIER_LIMITS['EC2'])
                overage_hours = max(0, hours_used - self.FREE_TIER_LIMITS['EC2'])
                
                free_cost = 0.0  # Free Tier covers it
                standard_cost = hours_used * self.FALLBACK_PRICING['EC2']
                overage_cost = overage_hours * self.FALLBACK_PRICING['EC2']
                
                result['breakdown'][service] = {
                    'free_tier_hours': free_tier_hours,
                    'overage_hours': overage_hours,
                    'free_cost': free_cost + overage_cost,
                    'standard_cost': standard_cost
                }
                
                result['free_tier_cost'] += free_cost + overage_cost
                result['standard_cost'] += standard_cost
            
            elif service_upper == 'S3':
                # Assume 1GB storage for the duration
                storage_gb = 1.0
                free_tier_gb = min(storage_gb, self.FREE_TIER_LIMITS['S3'])
                overage_gb = max(0, storage_gb - self.FREE_TIER_LIMITS['S3'])
                
                free_cost = overage_gb * self.FALLBACK_PRICING['S3'] * (duration_hours / 24 / 30)
                standard_cost = storage_gb * self.FALLBACK_PRICING['S3'] * (duration_hours / 24 / 30)
                
                result['breakdown'][service] = {
                    'storage_gb': storage_gb,
                    'free_tier_gb': free_tier_gb,
                    'free_cost': free_cost,
                    'standard_cost': standard_cost
                }
                
                result['free_tier_cost'] += free_cost
                result['standard_cost'] += standard_cost
            
            elif service_upper == 'LAMBDA':
                # Assume 10,000 requests per hour
                requests = int(10000 * duration_hours)
                free_tier_requests = min(requests, self.FREE_TIER_LIMITS['Lambda'])
                overage_requests = max(0, requests - self.FREE_TIER_LIMITS['Lambda'])
                
                free_cost = overage_requests * self.FALLBACK_PRICING['Lambda']
                standard_cost = requests * self.FALLBACK_PRICING['Lambda']
                
                result['breakdown'][service] = {
                    'requests': requests,
                    'free_tier_requests': free_tier_requests,
                    'free_cost': free_cost,
                    'standard_cost': standard_cost
                }
                
                result['free_tier_cost'] += free_cost
                result['standard_cost'] += standard_cost
            
            elif service_upper == 'CODEBUILD':
                # Assume 30 minutes of build time
                build_minutes = 30
                free_tier_minutes = min(build_minutes, self.FREE_TIER_LIMITS['CodeBuild'])
                overage_minutes = max(0, build_minutes - self.FREE_TIER_LIMITS['CodeBuild'])
                
                free_cost = overage_minutes * self.FALLBACK_PRICING['CodeBuild']
                standard_cost = build_minutes * self.FALLBACK_PRICING['CodeBuild']
                
                result['breakdown'][service] = {
                    'build_minutes': build_minutes,
                    'free_tier_minutes': free_tier_minutes,
                    'free_cost': free_cost,
                    'standard_cost': standard_cost
                }
                
                result['free_tier_cost'] += free_cost
                result['standard_cost'] += standard_cost
            
            else:
                # Other services - use fallback pricing
                if service_upper in self.FALLBACK_PRICING:
                    cost = duration_hours * self.FALLBACK_PRICING[service_upper]
                    result['breakdown'][service] = {
                        'free_cost': cost,
                        'standard_cost': cost
                    }
                    result['free_tier_cost'] += cost
                    result['standard_cost'] += cost
        
        # Calculate potential savings
        result['potential_savings'] = result['standard_cost'] - result['free_tier_cost']
        
        # Round values
        result['free_tier_cost'] = round(result['free_tier_cost'], 4)
        result['standard_cost'] = round(result['standard_cost'], 4)
        result['potential_savings'] = round(result['potential_savings'], 4)
        
        return result
    
    def get_free_tier_status(self) -> Dict:
        """Get basic Free Tier status information"""
        return {
            'limits': self.FREE_TIER_LIMITS,
            'note': 'This is a simplified Free Tier tracker. For detailed tracking, use the full pricing analysis system.',
            'recommendation': 'Monitor your AWS billing dashboard for accurate usage tracking.'
        }
    
    def format_cost_summary(self, cost_data: Dict) -> str:
        """Format cost data as a readable summary"""
        lines = []
        lines.append(f"💰 Cost Estimate ({cost_data['duration_hours']:.1f} hours)")
        lines.append(f"   Free Tier: ${cost_data['free_tier_cost']:.4f}")
        lines.append(f"   Standard:  ${cost_data['standard_cost']:.4f}")
        
        if cost_data['potential_savings'] > 0:
            lines.append(f"   💡 Savings: ${cost_data['potential_savings']:.4f}")
        
        return '\n'.join(lines)


# Simple usage functions for lab manager integration
def estimate_simple_cost(services: List[str], duration_hours: float) -> float:
    """Simple cost estimation function for lab manager"""
    helper = SimplePricingHelper()
    result = helper.estimate_lab_cost(services, duration_hours)
    return result['standard_cost']

def get_cost_breakdown(services: List[str], duration_hours: float) -> Dict:
    """Get detailed cost breakdown for lab manager"""
    helper = SimplePricingHelper()
    return helper.estimate_lab_cost(services, duration_hours)

def format_pricing_info(services: List[str], duration_hours: float) -> str:
    """Format pricing information for display"""
    helper = SimplePricingHelper()
    cost_data = helper.estimate_lab_cost(services, duration_hours)
    return helper.format_cost_summary(cost_data)


if __name__ == "__main__":
    # Simple test
    helper = SimplePricingHelper()
    
    services = ['EC2', 'S3', 'Lambda']
    duration = 2.0
    
    result = helper.estimate_lab_cost(services, duration)
    print("Simple Pricing Test:")
    print("=" * 40)
    print(helper.format_cost_summary(result))
    print("\nDetailed breakdown:")
    print(json.dumps(result, indent=2))