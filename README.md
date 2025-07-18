# DevOps & Kubernetes Certification Labs

A comprehensive collection of hands-on laboratories designed to prepare for multiple DevOps and container orchestration certifications. These labs provide practical experience with AWS DevOps services, Kubernetes, Docker, and industry best practices through real-world scenarios.

## 🎯 Overview

This repository contains structured learning paths covering:

### AWS Certified DevOps Engineer - Professional
All domains of the AWS DevOps Professional certification:

- **Domain 1**: SDLC Automation (22% of exam)
- **Domain 2**: Configuration Management and IaC (19% of exam)  
- **Domain 3**: Monitoring and Logging (15% of exam)
- **Domain 4**: Policies and Standards Automation (10% of exam)
- **Domain 5**: Incident and Event Response (18% of exam)
- **Domain 6**: High Availability, Fault Tolerance, and Disaster Recovery (16% of exam)

## 📚 Laboratory Structure

### 🚀 CI/CD Pipeline Labs (`AWSDevOpsLabs/01-cicd/`)

Comprehensive labs covering continuous integration and deployment pipelines with AWS native services.

#### CodePipeline Lab
- **Objective**: Multi-stage CI/CD pipeline with source, build, test, and deploy stages
- **Services**: CodePipeline, S3, CodeBuild, CloudWatch
- **Features**:
  - S3-based source control (no external Git provider needed)
  - Automated pipeline triggering
  - Artifact management and versioning
  - Pipeline monitoring and notifications
  - Rollback procedures and failure handling
- **Duration**: 2-3 hours
- **Cost**: $2-5/month for regular use

#### CodeBuild Lab  
- **Objective**: Advanced build automation with multiple environments and optimization strategies
- **Services**: CodeBuild, ECR, S3, CloudWatch Logs
- **Features**:
  - Multi-language build environments (Node.js, Python, Java, Docker)
  - Build caching strategies for performance optimization
  - Parallel build execution for complex applications
  - Custom Docker build images
  - Security scanning integration (Trivy, Bandit, OWASP)
  - Build performance monitoring and optimization
- **Duration**: 3-4 hours
- **Cost**: $5-15/month for regular use

#### CodeDeploy Lab
- **Objective**: Deployment strategies with automated rollback and health monitoring
- **Services**: CodeDeploy, EC2, ECS, Auto Scaling Groups, Application Load Balancer
- **Features**:
  - Blue-green deployments for zero-downtime updates
  - In-place rolling deployments with health checks
  - ECS container deployment strategies
  - Automated rollback scenarios and failure detection
  - Deployment monitoring and alerting
  - Load balancer integration and traffic management
- **Duration**: 3-4 hours
- **Cost**: $15-30/day for active lab use

### 🏗️ Infrastructure as Code Labs (`AWSDevOpsLabs/02-iac/`)
*Coming Soon*
- CloudFormation advanced patterns
- AWS CDK development workflows
- Terraform integration with AWS
- Infrastructure testing and validation

### 📊 Monitoring and Logging Labs (`AWSDevOpsLabs/03-monitoring/`)
*Coming Soon*
- CloudWatch advanced monitoring
- X-Ray distributed tracing
- ELK stack on AWS
- Custom metrics and dashboards

### 🔒 Security and Compliance Labs (`AWSDevOpsLabs/04-security/`)
*Coming Soon*
- AWS Config compliance automation
- Security scanning in pipelines
- Secrets management with AWS Secrets Manager
- IAM policy automation

### 🚨 Incident Response Labs (`AWSDevOpsLabs/05-deployment/`)
*Coming Soon*
- Automated incident response
- Chaos engineering practices
- Disaster recovery automation
- Multi-region deployment strategies

### 🔗 Integration Labs (`AWSDevOpsLabs/06-integration/`)
*Coming Soon*
- Third-party tool integrations
- Hybrid cloud scenarios
- API Gateway and microservices
- Event-driven architectures

## ☸️ Kubernetes & Container Labs (`kubernetes/`)

Comprehensive hands-on laboratories for **Certified Kubernetes Administrator (CKA)** certification preparation, covering containerization fundamentals through advanced Kubernetes orchestration.

### 🐳 Container Labs (`kubernetes/container_labs/`)

Foundation laboratories covering Docker containerization concepts and multi-container applications.

#### Lab 1: Docker Fundamentals
- **Objective**: Create your first Docker container from scratch
- **Technologies**: Docker, Alpine Linux, Shell scripting
- **Features**:
  - Dockerfile creation and best practices
  - Image building and container execution
  - Understanding layers and caching
  - Basic container lifecycle management
- **Duration**: 1-2 hours
- **Level**: Beginner

#### Lab 2: Multi-stage Docker Builds
- **Objective**: Optimize Docker images using multi-stage builds
- **Technologies**: Node.js, Webpack, Nginx, Docker
- **Features**:
  - Modern web application with build pipeline
  - Multi-stage Dockerfile optimization
  - Image size reduction (90%+ smaller)
  - Production-ready static file serving
- **Duration**: 2-3 hours
- **Level**: Intermediate

#### Lab 3: Multi-Container Applications
- **Objective**: Orchestrate backend and database services
- **Technologies**: Node.js, PostgreSQL, Docker Compose
- **Features**:
  - REST API with database connectivity
  - Service orchestration with Docker Compose
  - Volume management and data persistence
  - Environment variable configuration
  - Inter-container networking
- **Duration**: 3-4 hours
- **Level**: Intermediate

#### Final Lab: Full-Stack Application
- **Objective**: Complete 3-tier application deployment
- **Technologies**: React, Node.js, PostgreSQL, Docker Compose
- **Features**:
  - Frontend, backend, and database integration
  - Production-ready multi-container setup
  - Advanced Docker Compose configurations
  - Testing and deployment strategies
- **Duration**: 4-5 hours
- **Level**: Advanced

### ☸️ Kubernetes Labs (`kubernetes/kubernetes_lab/`)

Progressive laboratory series covering all aspects of Kubernetes administration and application deployment.

#### Core Kubernetes Concepts (Labs 1-6)
- **Lab 1**: Pod Basics - Creating and managing your first pods
- **Lab 2**: ReplicaSets - Ensuring application availability
- **Lab 3**: Deployments - Managing application updates and rollbacks
- **Lab 4**: Services - Exposing applications and load balancing
- **Lab 5**: ConfigMaps & Secrets - Configuration and sensitive data management
- **Lab 6**: Volumes - Persistent storage and data management

#### Advanced Kubernetes Features (Labs 7-10)
- **Lab 7**: Namespaces - Resource isolation and multi-tenancy
- **Lab 8**: Ingress Controllers - External access and routing
- **Lab 9**: Monitoring & Logging - Observability and troubleshooting
- **Lab 10**: RBAC & Security - Authentication, authorization, and security policies

#### Real-World Applications (Labs 11-12)
- **Lab 11**: Multi-tier Application - Complete application deployment
- **Lab 12**: CI/CD Integration - Automated deployment pipelines

#### Package Management with Helm (Labs 13-15)
- **Lab 13**: Helm Introduction - Package manager fundamentals
- **Lab 14**: Creating Helm Charts - Custom application packaging
- **Lab 15**: Advanced Helm - Templating, dependencies, and lifecycle management

### 🎓 CKA Certification Preparation

#### Exam Domains Coverage
- **Cluster Architecture, Installation & Configuration** (25%)
- **Workloads & Scheduling** (15%)
- **Services & Networking** (20%)
- **Storage** (10%)
- **Troubleshooting** (30%)

#### Key Skills Developed
- ✅ Container orchestration and management
- ✅ Kubernetes cluster administration
- ✅ Application deployment and scaling
- ✅ Network configuration and service mesh
- ✅ Storage management and persistence
- ✅ Security and access control
- ✅ Monitoring and troubleshooting
- ✅ Package management with Helm

### 🚀 Getting Started with Kubernetes Labs

#### Prerequisites
- **Docker**: Installed and running
- **Kubernetes Cluster**: minikube, kind, or cloud provider
- **kubectl**: Kubernetes command-line tool
- **Helm**: Package manager (for Helm labs)

#### Quick Start
1. **Start with Container Labs:**
   ```bash
   cd kubernetes/container_labs/lab1
   cat README.md
   ```

2. **Progress to Kubernetes Labs:**
   ```bash
   cd kubernetes/kubernetes_lab/lab01-pod-basics
   cat README.md
   ```

3. **Follow the progressive learning path**
4. **Practice hands-on exercises**
5. **Complete certification-focused scenarios**

### 💡 Learning Approach
- **No Copy-Paste**: Learn by doing, not copying solutions
- **Progressive Complexity**: Each lab builds on previous knowledge
- **Real-World Scenarios**: Practical applications and use cases
- **Official Documentation**: Links to authoritative resources
- **Troubleshooting Focus**: Problem-solving and debugging skills

## 🚀 Getting Started

### Prerequisites

1. **AWS Account**: Active AWS account with appropriate permissions
2. **AWS CLI**: Installed and configured with your credentials
   ```bash
   aws configure
   ```
3. **Tools**: Git, text editor, and terminal access
4. **Permissions**: IAM user/role with sufficient permissions for each lab

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd DevOpsLab
   ```

2. **Choose a lab and navigate to its directory:**
   ```bash
   cd AWSDevOpsLabs/01-cicd/codepipeline
   ```

3. **Review the lab guide:**
   ```bash
   cat lab-guide.md
   ```

4. **Run the provisioning script:**
   ```bash
   # On Linux/Mac
   ./scripts/provision-pipeline.sh
   
   # On Windows
   bash scripts/provision-pipeline.sh
   ```

5. **Follow the lab guide for hands-on exercises**

6. **Clean up resources when finished:**
   ```bash
   ./scripts/cleanup-pipeline.sh
   ```

## 📋 Lab Management

### Cost Management
- Each lab includes cost estimates and cleanup procedures
- Use AWS Cost Explorer to monitor spending
- Set up billing alerts for cost control
- Labs are designed to use free tier resources when possible

### Session Management
- Each lab creates a `lab-session-info.txt` file with important details
- Save this file for reference during the lab
- Contains resource names, URLs, and CLI commands
- Automatically cleaned up during lab cleanup

### Troubleshooting
- Each lab includes comprehensive troubleshooting guides
- Common issues and solutions are documented
- Debugging commands and diagnostic procedures provided
- AWS Console links for monitoring and verification

## 🎓 Certification Preparation

### Exam Domains Coverage
- **Domain 1 (SDLC Automation)**: CI/CD Pipeline Labs
- **Domain 2 (Configuration Management)**: IaC Labs
- **Domain 3 (Monitoring and Logging)**: Monitoring Labs
- **Domain 4 (Policies and Standards)**: Security Labs
- **Domain 5 (Incident Response)**: Deployment Labs
- **Domain 6 (High Availability)**: Integration Labs

### Study Tips
- Complete labs in order of complexity
- Practice CLI commands and automation scripts
- Understand the "why" behind each configuration
- Review AWS documentation for services used
- Take notes on key concepts and best practices

### Exam-Specific Features
- Real-world scenarios matching exam questions
- Hands-on experience with exam topics
- Best practices and common pitfalls
- Performance optimization techniques
- Security and compliance considerations

## 🛠️ Technical Requirements

### AWS Services Used
- **Compute**: EC2, ECS, Lambda, Auto Scaling Groups
- **Storage**: S3, EBS
- **Networking**: VPC, ALB, Security Groups
- **Developer Tools**: CodePipeline, CodeBuild, CodeDeploy
- **Management**: CloudFormation, CloudWatch, IAM
- **Container**: ECR, ECS, Fargate

### Local Development
- **Operating Systems**: Windows, macOS, Linux
- **Shell**: Bash (recommended), PowerShell, Command Prompt
- **Languages**: Python, Node.js, Java (for specific labs)
- **Tools**: Docker, Git, AWS CLI

## 📊 Progress Tracking

### Lab Completion Checklist

#### AWS DevOps Labs
- [ ] CI/CD Pipeline Labs (3 labs)
- [ ] Infrastructure as Code Labs (Coming Soon)
- [ ] Monitoring and Logging Labs (Coming Soon)
- [ ] Security and Compliance Labs (Coming Soon)
- [ ] Incident Response Labs (Coming Soon)
- [ ] Integration Labs (Coming Soon)

#### Kubernetes & Container Labs
- [ ] Container Labs (4 labs)
- [ ] Kubernetes Core Concepts Labs (6 labs)
- [ ] Advanced Kubernetes Labs (4 labs)
- [ ] Real-World Application Labs (2 labs)
- [ ] Helm Package Management Labs (3 labs)

### Skills Assessment
Track your progress in key areas:

#### AWS DevOps Skills
- [ ] Pipeline automation and orchestration
- [ ] Infrastructure provisioning and management
- [ ] Monitoring and observability
- [ ] Security and compliance automation
- [ ] Incident response and disaster recovery
- [ ] Integration and deployment strategies

#### Kubernetes & Container Skills
- [ ] Container orchestration and management
- [ ] Kubernetes cluster administration
- [ ] Application deployment and scaling
- [ ] Network configuration and service mesh
- [ ] Storage management and persistence
- [ ] Security and access control

## 🤝 Contributing

Contributions are welcome! Please read the contributing guidelines before submitting pull requests.

### Areas for Contribution
- Additional lab scenarios
- Bug fixes and improvements
- Documentation enhancements
- Cost optimization suggestions
- New AWS service integrations

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Issues**: Report bugs and request features via GitHub Issues
- **Documentation**: Comprehensive lab guides included
- **Community**: Share experiences and solutions
- **Updates**: Regular updates with new AWS services and features

## 🔗 Additional Resources

### AWS DevOps Professional
- [AWS DevOps Professional Exam Guide](https://aws.amazon.com/certification/certified-devops-engineer-professional/)
- [AWS DevOps Documentation](https://docs.aws.amazon.com/devops/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS DevOps Blog](https://aws.amazon.com/blogs/devops/)

### Kubernetes & CKA Certification
- [CKA Certification Exam Guide](https://www.cncf.io/certification/cka/)
- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Kubernetes Interactive Tutorials](https://kubernetes.io/docs/tutorials/)
- [CNCF Kubernetes Blog](https://kubernetes.io/blog/)
- [Helm Documentation](https://helm.sh/docs/)
- [Docker Official Documentation](https://docs.docker.com/)

---

**⚠️ Important**: These labs create real AWS resources that may incur costs. Always run cleanup scripts when finished and monitor your AWS billing dashboard.

**🎯 Goal**: Master AWS DevOps services and Kubernetes through hands-on practice and earn your AWS Certified DevOps Engineer - Professional and Certified Kubernetes Administrator (CKA) certifications!