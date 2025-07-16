#!/bin/bash

# Advanced CodeBuild Lab Provisioning Script
# This script provisions multiple CodeBuild projects with different build environments

set -e

# Configuration
PROJECT_NAME="advanced-codebuild-lab"
STACK_NAME="${PROJECT_NAME}-stack"
TEMPLATE_FILE="templates/advanced-codebuild-projects.yaml"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Generate unique bucket names
TIMESTAMP=$(date +%s)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ARTIFACT_BUCKET="${PROJECT_NAME}-artifacts-${ACCOUNT_ID}-${TIMESTAMP}"
CACHE_BUCKET="${PROJECT_NAME}-cache-${ACCOUNT_ID}-${TIMESTAMP}"

echo "=== Advanced CodeBuild Lab Provisioning ==="
echo "Project Name: $PROJECT_NAME"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Artifact Bucket: $ARTIFACT_BUCKET"
echo "Cache Bucket: $CACHE_BUCKET"
echo

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS CLI is not configured or credentials are invalid"
    echo "Please run 'aws configure' to set up your credentials"
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file $TEMPLATE_FILE not found"
    echo "Please ensure you're running this script from the codebuild directory"
    exit 1
fi

# Create sample source code for different build types
echo "Creating sample source code for different build environments..."

# Create Node.js sample project
mkdir -p sample-projects/nodejs-app
cat > sample-projects/nodejs-app/package.json << 'EOF'
{
  "name": "codebuild-nodejs-sample",
  "version": "1.0.0",
  "description": "Sample Node.js application for CodeBuild lab",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "jest",
    "build": "webpack --mode production",
    "lint": "eslint src/"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "eslint": "^8.0.0",
    "webpack": "^5.0.0",
    "webpack-cli": "^4.0.0"
  }
}
EOF

cat > sample-projects/nodejs-app/index.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({ 
    message: 'Hello from CodeBuild Node.js Lab!',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', uptime: process.uptime() });
});

if (require.main === module) {
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}

module.exports = app;
EOF

cat > sample-projects/nodejs-app/index.test.js << 'EOF'
const request = require('supertest');
const app = require('./index');

describe('Express App', () => {
  test('GET / should return welcome message', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.body.message).toContain('Hello from CodeBuild');
  });

  test('GET /health should return health status', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('healthy');
  });
});
EOF

# Create Python sample project
mkdir -p sample-projects/python-app
cat > sample-projects/python-app/requirements.txt << 'EOF'
flask==2.3.0
pytest==7.4.0
pytest-cov==4.1.0
requests==2.31.0
EOF

cat > sample-projects/python-app/app.py << 'EOF'
from flask import Flask, jsonify
import os
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        'message': 'Hello from CodeBuild Python Lab!',
        'timestamp': datetime.utcnow().isoformat(),
        'python_version': os.sys.version
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
EOF

cat > sample-projects/python-app/test_app.py << 'EOF'
import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_hello(client):
    response = client.get('/')
    assert response.status_code == 200
    data = response.get_json()
    assert 'Hello from CodeBuild' in data['message']

def test_health(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'
EOF

# Create Java sample project
mkdir -p sample-projects/java-app/src/main/java/com/example
mkdir -p sample-projects/java-app/src/test/java/com/example

cat > sample-projects/java-app/pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>codebuild-java-sample</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.0.0-M7</version>
            </plugin>
            <plugin>
                <groupId>org.jacoco</groupId>
                <artifactId>jacoco-maven-plugin</artifactId>
                <version>0.8.8</version>
                <executions>
                    <execution>
                        <goals>
                            <goal>prepare-agent</goal>
                        </goals>
                    </execution>
                    <execution>
                        <id>report</id>
                        <phase>test</phase>
                        <goals>
                            <goal>report</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
EOF

cat > sample-projects/java-app/src/main/java/com/example/App.java << 'EOF'
package com.example;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class App {
    public static void main(String[] args) {
        System.out.println("Hello from CodeBuild Java Lab!");
        System.out.println("Current time: " + getCurrentTime());
    }
    
    public static String getCurrentTime() {
        return LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
    }
    
    public static String getGreeting() {
        return "Hello from CodeBuild Java Lab!";
    }
}
EOF

cat > sample-projects/java-app/src/test/java/com/example/AppTest.java << 'EOF'
package com.example;

import org.junit.Test;
import static org.junit.Assert.*;

public class AppTest {
    @Test
    public void testGetGreeting() {
        String greeting = App.getGreeting();
        assertNotNull(greeting);
        assertTrue(greeting.contains("Hello from CodeBuild"));
    }
    
    @Test
    public void testGetCurrentTime() {
        String time = App.getCurrentTime();
        assertNotNull(time);
        assertFalse(time.isEmpty());
    }
}
EOF

# Create Docker sample project
mkdir -p sample-projects/docker-app
cat > sample-projects/docker-app/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

USER node

CMD ["npm", "start"]
EOF

cat > sample-projects/docker-app/package.json << 'EOF'
{
  "name": "codebuild-docker-sample",
  "version": "1.0.0",
  "description": "Sample Docker application for CodeBuild lab",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "echo 'No tests specified'"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

cat > sample-projects/docker-app/server.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from CodeBuild Docker Lab!',
    timestamp: new Date().toISOString(),
    container: true
  });
});

app.listen(port, () => {
  console.log(`Docker app listening on port ${port}`);
});
EOF

# Create zip files for each sample project
echo "Creating source archives..."
cd sample-projects
for project in */; do
    project_name=${project%/}
    zip -r "../${project_name}-source.zip" "$project"
done
cd ..

echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        ProjectName="$PROJECT_NAME" \
        ArtifactBucketName="$ARTIFACT_BUCKET" \
        CacheBucketName="$CACHE_BUCKET" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    --tags Project="$PROJECT_NAME" Environment="Lab"

if [ $? -eq 0 ]; then
    echo "✅ Stack deployment successful!"
else
    echo "❌ Stack deployment failed!"
    exit 1
fi

# Upload sample source code to S3
echo "Uploading sample source code to S3..."
for zip_file in *-source.zip; do
    aws s3 cp "$zip_file" "s3://$ARTIFACT_BUCKET/" --region "$REGION"
done

# Get stack outputs
echo "Retrieving stack outputs..."
NODEJS_PROJECT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`NodeJSBuildProject`].OutputValue' \
    --output text \
    --region "$REGION")

PYTHON_PROJECT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`PythonBuildProject`].OutputValue' \
    --output text \
    --region "$REGION")

JAVA_PROJECT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`JavaBuildProject`].OutputValue' \
    --output text \
    --region "$REGION")

DOCKER_PROJECT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`DockerBuildProject`].OutputValue' \
    --output text \
    --region "$REGION")

PARALLEL_PROJECT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ParallelBuildProject`].OutputValue' \
    --output text \
    --region "$REGION")

ECR_REPO=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECRRepository`].OutputValue' \
    --output text \
    --region "$REGION")

# Create lab session info file
cat > lab-session-info.txt << EOF
=== Advanced CodeBuild Lab Session Information ===
Created: $(date)
Stack Name: $STACK_NAME
Region: $REGION

Build Projects Created:
- Node.js Project: $NODEJS_PROJECT
- Python Project: $PYTHON_PROJECT
- Java Project: $JAVA_PROJECT
- Docker Project: $DOCKER_PROJECT
- Parallel Project: $PARALLEL_PROJECT

Resources:
- Artifact Bucket: $ARTIFACT_BUCKET
- Cache Bucket: $CACHE_BUCKET
- ECR Repository: $ECR_REPO

Sample Projects Available:
- nodejs-app-source.zip (Express.js application)
- python-app-source.zip (Flask application)
- java-app-source.zip (Maven application)
- docker-app-source.zip (Containerized Node.js app)

Next Steps:
1. Start builds using the AWS Console or CLI
2. Monitor build logs and performance
3. Experiment with different build configurations
4. Test caching effectiveness with multiple builds

Example CLI Commands:
aws codebuild start-build --project-name $NODEJS_PROJECT --source-location s3://$ARTIFACT_BUCKET/nodejs-app-source.zip
aws codebuild start-build --project-name $PYTHON_PROJECT --source-location s3://$ARTIFACT_BUCKET/python-app-source.zip

Cleanup:
Run './cleanup-codebuild.sh' to remove all resources when done.
EOF

# Clean up temporary files
rm -rf sample-projects
rm -f *-source.zip

echo
echo "🎉 Advanced CodeBuild Lab Environment Ready!"
echo
cat lab-session-info.txt
echo
echo "Lab session information saved to: lab-session-info.txt"