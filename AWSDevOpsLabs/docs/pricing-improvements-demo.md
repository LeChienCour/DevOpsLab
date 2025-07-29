# Pricing Analysis Improvements Demo

## Overview

The lab manager now uses **real-time AWS pricing data** instead of hardcoded estimates, and has **improved difficulty detection** based on multiple factors.

## Key Improvements

### 1. Real-Time Cost Estimation

**Before (Hardcoded):**
```python
service_costs = {
    'EC2': 0.0104,  # Fixed t3.micro price
    'S3': 0.023,    # Fixed storage price
    'Lambda': 0.0001,
    # ... static values
}
```

**After (Dynamic):**
```python
# Uses real AWS Pricing API data
comparison = self.cost_comparison.create_side_by_side_comparison(lab_config, duration_hours)
return comparison.get('standard_pricing', {}).get('total_cost', 0.0)
```

### 2. Enhanced Difficulty Detection

**Before (Simple Keywords):**
```python
if any(word in content.lower() for word in ['advanced', 'complex']):
    difficulty = "advanced"
elif any(word in content.lower() for word in ['basic', 'simple']):
    difficulty = "beginner"
```

**After (Multi-Factor Analysis):**
- **Content Analysis**: 30+ keywords across difficulty levels
- **Service Complexity**: Complex services (EKS, ECS) vs simple (S3, IAM)
- **Duration Impact**: Longer labs tend to be more complex
- **Service Count**: More services = higher complexity
- **Prerequisites**: Mentions of required experience

### 3. Improved Lab Listing

**Before:**
```
ID: cicd-pipeline-lab
Name: CI/CD Pipeline Lab
Estimated Cost: $2.50
```

**After:**
```
ID: cicd-pipeline-lab
Name: CI/CD Pipeline Lab
Estimated Cost: $2.50
  📊 Real-time Pricing Analysis:
    Free Tier Cost: $0.0000
    Standard Cost: $2.1234
    Potential Savings: $2.1234
    📉 Difference from estimate: -$0.3766
```

## Example Scenarios

### Scenario 1: Simple S3 Lab

**Content:**
```markdown
# Introduction to AWS S3
This is a simple, basic tutorial for getting started with S3.
A hello world example for beginners.
```

**Analysis:**
- **Services**: ['S3'] (1 service, simple)
- **Duration**: 45 minutes (short)
- **Keywords**: "simple", "basic", "tutorial", "beginners"
- **Result**: `difficulty = "beginner"`

### Scenario 2: Advanced Microservices Lab

**Content:**
```markdown
# Advanced Multi-Tier Application Deployment
This is a complex, production-grade deployment using microservices 
architecture with Kubernetes, service mesh, and advanced monitoring.

## Prerequisites
- Experience with Docker and Kubernetes
- Knowledge of AWS networking
```

**Analysis:**
- **Services**: ['EKS', 'ECS', 'RDS', 'ElastiCache', 'API Gateway'] (5+ services, complex)
- **Duration**: 240 minutes (long)
- **Keywords**: "advanced", "complex", "production-grade", "microservices"
- **Prerequisites**: Mentions experience requirements
- **Result**: `difficulty = "advanced"`

### Scenario 3: Cost Estimation Comparison

**Lab Configuration:**
- EC2 t3.micro for 2 hours
- S3 with 1GB storage
- Lambda with 10,000 requests

**Old Estimation:**
```
EC2: 2 * $0.0104 = $0.0208
S3:  2 * $0.023  = $0.046
Base infrastructure: $1.00
Total: $1.0668
```

**New Estimation (with real pricing):**
```
Real-time AWS Pricing API call:
- Current t3.micro rate: $0.0104/hour
- Current S3 standard rate: $0.023/GB
- Lambda pricing: $0.0000002/request
- Regional variations considered
- Free Tier eligibility checked
Total: $0.0234 (much more accurate!)
```

## Benefits

### 1. Accuracy
- **Real-time pricing** reflects current AWS rates
- **Regional differences** are considered
- **Free Tier benefits** are calculated

### 2. Intelligence
- **Multi-factor difficulty** assessment
- **Service complexity** scoring
- **Duration and prerequisite** consideration

### 3. User Experience
- **Clear cost breakdown** with Free Tier vs standard
- **Budget warnings** when approaching limits
- **Savings potential** clearly displayed

## Usage Examples

### List Labs with Real-Time Pricing
```bash
python lab-manager.py list --pricing
```

### Analyze Specific Lab Costs
```bash
python lab-manager.py pricing cicd-pipeline-lab
```

### Check Free Tier Status
```bash
python lab-manager.py free-tier
```

### Generate Cost Report
```bash
python lab-manager.py cost-report --output costs.json
```

## Technical Implementation

### Cost Estimation Flow
1. **Check if pricing analysis available** (AWS credentials + modules)
2. **Map services to resources** (EC2 → t3.micro, S3 → 1GB, etc.)
3. **Call real pricing API** via cost comparison system
4. **Return accurate cost** or fall back to hardcoded estimates

### Difficulty Detection Algorithm
1. **Content keyword analysis** (weighted scoring)
2. **Service complexity assessment** (complex vs simple services)
3. **Duration factor** (longer = more complex)
4. **Service count** (more services = higher complexity)
5. **Prerequisites analysis** (experience requirements)
6. **Final scoring** → beginner/intermediate/advanced

## Error Handling

The system gracefully handles:
- **Missing AWS credentials** → Falls back to hardcoded estimates
- **API failures** → Uses cached data or fallback
- **Missing pricing modules** → Shows warning, continues with basic functionality
- **Invalid lab configurations** → Provides reasonable defaults

This ensures the lab manager always works, even without full pricing integration.