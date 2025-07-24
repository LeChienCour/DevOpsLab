# AWS CDK Lab Guide

This lab covers AWS Cloud Development Kit (CDK) fundamentals for infrastructure provisioning using TypeScript.

## Learning Objectives

By completing this lab, you will:
- Understand CDK concepts and architecture
- Create infrastructure using TypeScript CDK
- Deploy multi-tier applications with CDK
- Compare CDK with CloudFormation approaches
- Understand CDK best practices

## Prerequisites

- Node.js 18+ and npm installed
- AWS CLI configured with appropriate permissions
- AWS CDK CLI installed: `npm install -g aws-cdk`
- Basic TypeScript knowledge

## CDK vs CloudFormation

| Feature | CDK | CloudFormation |
|---------|-----|----------------|
| Language | TypeScript/Python/Java | YAML/JSON |
| Reusability | High (constructs) | Medium (nested stacks) |
| Learning Curve | Moderate | Low |
| IDE Support | Excellent | Basic |
| Testing | Unit tests possible | Limited |

## Simple CDK Example

Here's a basic CDK stack that creates a VPC and S3 bucket:

```typescript
import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as s3 from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export class SimpleStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create VPC
    const vpc = new ec2.Vpc(this, 'MyVpc', {
      maxAzs: 2,
      natGateways: 1
    });

    // Create S3 bucket
    const bucket = new s3.Bucket(this, 'MyBucket', {
      encryption: s3.BucketEncryption.S3_MANAGED,
      removalPolicy: cdk.RemovalPolicy.DESTROY
    });

    // Outputs
    new cdk.CfnOutput(this, 'VpcId', {
      value: vpc.vpcId,
      description: 'VPC ID'
    });

    new cdk.CfnOutput(this, 'BucketName', {
      value: bucket.bucketName,
      description: 'S3 Bucket Name'
    });
  }
}
```

## Getting Started

1. **Initialize a new CDK project:**
   ```bash
   mkdir my-cdk-app
   cd my-cdk-app
   cdk init app --language typescript
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Bootstrap CDK (first time only):**
   ```bash
   cdk bootstrap
   ```

4. **Deploy the stack:**
   ```bash
   cdk deploy
   ```

5. **Clean up:**
   ```bash
   cdk destroy
   ```

## CDK Best Practices

### 1. Use Constructs
```typescript
// Create reusable constructs
export class WebServiceConstruct extends Construct {
  constructor(scope: Construct, id: string, props: WebServiceProps) {
    super(scope, id);
    
    // Define your reusable infrastructure here
  }
}
```

### 2. Environment Configuration
```typescript
const app = new cdk.App();

new MyStack(app, 'DevStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
  environment: 'dev'
});
```

### 3. Tagging Strategy
```typescript
cdk.Tags.of(app).add('Project', 'DevOpsLab');
cdk.Tags.of(app).add('Environment', environment);
cdk.Tags.of(app).add('ManagedBy', 'CDK');
```

### 4. Resource Naming
```typescript
const bucket = new s3.Bucket(this, 'DataBucket', {
  bucketName: `my-app-data-${environment}-${this.account}`
});
```

## Common CDK Patterns

### Multi-Stack Application
```typescript
// Database stack
const dbStack = new DatabaseStack(app, 'Database', { env });

// Application stack that depends on database
const appStack = new ApplicationStack(app, 'Application', {
  env,
  database: dbStack.database
});

appStack.addDependency(dbStack);
```

### Cross-Stack References
```typescript
// Export from one stack
new cdk.CfnOutput(this, 'VpcId', {
  value: vpc.vpcId,
  exportName: 'MyVpcId'
});

// Import in another stack
const vpcId = cdk.Fn.importValue('MyVpcId');
```

## CDK Commands

| Command | Description |
|---------|-------------|
| `cdk init` | Initialize new CDK project |
| `cdk synth` | Synthesize CloudFormation template |
| `cdk deploy` | Deploy stack to AWS |
| `cdk diff` | Show differences between deployed and local |
| `cdk destroy` | Delete stack from AWS |
| `cdk ls` | List all stacks in the app |

## Comparison with Other IaC Tools

### CDK Advantages
- **Type Safety**: Compile-time error checking
- **IDE Support**: IntelliSense and auto-completion
- **Reusability**: Create and share constructs
- **Testing**: Unit test your infrastructure
- **Familiar Languages**: Use TypeScript, Python, Java

### CDK Considerations
- **Learning Curve**: Requires programming knowledge
- **Complexity**: Can become complex for simple use cases
- **Debugging**: Harder to debug than declarative templates
- **Vendor Lock-in**: AWS-specific (though there's CDK for Terraform)

## When to Use CDK vs CloudFormation

**Use CDK when:**
- You have programming experience
- Need complex logic in infrastructure
- Want to create reusable components
- Require type safety and IDE support
- Building large, complex applications

**Use CloudFormation when:**
- Simple infrastructure requirements
- Team prefers declarative approach
- Need maximum AWS service coverage
- Want direct control over CloudFormation features

## Next Steps

1. **Explore CDK Constructs**: Check out the AWS Construct Library
2. **Learn CDK Patterns**: Study common architectural patterns
3. **CDK Pipelines**: Implement CI/CD with CDK Pipelines (advanced)
4. **Testing**: Write unit tests for your CDK code
5. **Custom Constructs**: Create your own reusable constructs

## Resources

- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/v2/guide/)
- [CDK API Reference](https://docs.aws.amazon.com/cdk/api/v2/)
- [CDK Workshop](https://cdkworkshop.com/)
- [CDK Examples](https://github.com/aws-samples/aws-cdk-examples)
- [Construct Hub](https://constructs.dev/)

## Alternative: Focus on CloudFormation and Terraform

For this DevOps certification lab, we recommend focusing on:

1. **CloudFormation** - Native AWS IaC with comprehensive coverage
2. **Terraform** - Multi-cloud IaC with excellent AWS support

Both tools provide:
- ✅ Production-ready implementations
- ✅ Comprehensive examples
- ✅ Best practices demonstrations
- ✅ Complete automation scripts
- ✅ Multi-environment support

The CloudFormation and Terraform labs in this repository provide complete, working examples that are immediately usable for learning and certification preparation.