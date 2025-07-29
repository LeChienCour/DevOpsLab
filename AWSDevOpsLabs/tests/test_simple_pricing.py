#!/usr/bin/env python3
"""
Simple test for pricing functionality
"""

import unittest
import os
import sys

# Add the scripts directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

try:
    from simple_pricing import SimplePricingHelper, estimate_simple_cost, get_cost_breakdown
    PRICING_AVAILABLE = True
except ImportError:
    PRICING_AVAILABLE = False

@unittest.skipUnless(PRICING_AVAILABLE, "Simple pricing module not available")
class TestSimplePricing(unittest.TestCase):
    """Simple tests for pricing functionality"""
    
    def setUp(self):
        """Set up test environment"""
        self.helper = SimplePricingHelper()
    
    def test_basic_cost_estimation(self):
        """Test basic cost estimation"""
        services = ['EC2', 'S3']
        duration = 2.0  # 2 hours
        
        result = self.helper.estimate_lab_cost(services, duration)
        
        self.assertIn('free_tier_cost', result)
        self.assertIn('standard_cost', result)
        self.assertIn('potential_savings', result)
        self.assertGreaterEqual(result['standard_cost'], 0)
    
    def test_free_tier_limits(self):
        """Test Free Tier limits are defined"""
        limits = self.helper.FREE_TIER_LIMITS
        
        self.assertIn('EC2', limits)
        self.assertIn('S3', limits)
        self.assertIn('Lambda', limits)
        self.assertEqual(limits['EC2'], 750)  # 750 hours
    
    def test_simple_functions(self):
        """Test simple utility functions"""
        services = ['EC2']
        duration = 1.0
        
        # Test simple cost estimation
        cost = estimate_simple_cost(services, duration)
        self.assertIsInstance(cost, float)
        self.assertGreater(cost, 0)
        
        # Test cost breakdown
        breakdown = get_cost_breakdown(services, duration)
        self.assertIn('breakdown', breakdown)
        self.assertIn('EC2', breakdown['breakdown'])
    
    def test_cost_formatting(self):
        """Test cost summary formatting"""
        services = ['EC2', 'S3']
        duration = 1.0
        
        result = self.helper.estimate_lab_cost(services, duration)
        summary = self.helper.format_cost_summary(result)
        
        self.assertIn('Cost Estimate', summary)
        self.assertIn('Free Tier:', summary)
        self.assertIn('Standard:', summary)


if __name__ == '__main__':
    unittest.main()