# AWS DevOps Labs Documentation Style Guide

This style guide provides standards and conventions for creating consistent documentation across all AWS DevOps Labs modules.

## General Principles

- **Be clear and concise**: Use simple language and avoid unnecessary jargon.
- **Be consistent**: Follow the same patterns and terminology throughout all documentation.
- **Be comprehensive**: Include all necessary information for users to complete labs successfully.
- **Be user-focused**: Write with the user's perspective and needs in mind.

## Markdown Formatting Standards

### Headers

Use ATX-style headers (with `#` symbols):

```markdown
# Top-level header (H1) - Use for document title only
## Second-level header (H2) - Use for main sections
### Third-level header (H3) - Use for subsections
#### Fourth-level header (H4) - Use for step titles or minor subsections
```

- Use title case for H1 and H2 headers (e.g., "Lab Guide Template")
- Use sentence case for H3 and below (e.g., "Creating an S3 bucket")
- Include only one H1 header per document (the title)

### Lists

For ordered (numbered) lists:

```markdown
1. First item
2. Second item
   1. Sub-item
   2. Sub-item
3. Third item
```

For unordered (bullet) lists:

```markdown
- Item one
- Item two
  - Sub-item
  - Sub-item
- Item three
```

- Use ordered lists for sequential steps
- Use unordered lists for non-sequential items
- Maintain consistent indentation for sub-items (2 spaces)

### Code Blocks

Always use fenced code blocks with language specification:

```markdown
​```bash
# This is a bash command
aws s3 ls
​```

​```json
{
  "key": "value"
}
​```
```

- Include language identifier for proper syntax highlighting
- Use `bash` for command-line examples
- Use `json`, `yaml`, `xml`, etc., for configuration files
- Include comments in code blocks to explain complex commands
- Show expected output when relevant

### Blockquotes

Use blockquotes for important notes, warnings, or tips:

```markdown
> **Note**: This is important information to be aware of.

> **Warning**: This action might result in charges to your AWS account.

> **Tip**: Here's a helpful shortcut to make this process easier.
```

### Tables

Use tables for structured information:

```markdown
| Service | Free Tier Eligible | Estimated Cost |
|---------|-------------------|----------------|
| EC2     | Yes               | $0.00-$1.00    |
| S3      | Yes               | $0.00-$0.50    |
```

- Include header row and alignment markers
- Keep tables simple and readable
- Use tables for comparing options or listing resources

### Links

Format links as follows:

```markdown
[Link text](URL)
```

- Use descriptive link text (avoid "click here" or "this link")
- For external links, use the full URL
- For internal links, use relative paths

### Emphasis

Use emphasis sparingly and consistently:

```markdown
*Italic text* for mild emphasis
**Bold text** for strong emphasis
```

- Use bold for UI elements, button names, and important terms
- Use italics for file names, paths, and mild emphasis

## Terminology Conventions

### AWS Service Names

- Use the official AWS service name with correct capitalization (e.g., "Amazon S3", "AWS Lambda")
- On first mention, use the full name; subsequent mentions can use the short form (e.g., "S3", "Lambda")
- Do not use AWS service abbreviations that aren't commonly recognized

### Technical Terms

- Define technical terms on first use
- Be consistent with technical terminology throughout all documentation
- Spell out acronyms on first use, followed by the acronym in parentheses
  - Example: "Continuous Integration/Continuous Deployment (CI/CD)"

### Commands and Parameters

- Use consistent naming for command parameters
- Indicate placeholder values with angle brackets and descriptive names
  - Example: `aws s3 cp <local-file-path> s3://<bucket-name>/`
- Use consistent capitalization for commands and parameters

## Visual Elements

### Screenshots

- Include screenshots for complex AWS Console interactions
- Crop screenshots to focus on relevant UI elements
- Use annotations (arrows, circles) to highlight important areas
- Include a descriptive caption
- Ensure screenshots are clear and readable at standard zoom levels
- Update screenshots when the AWS Console interface changes significantly

### Diagrams

For simple diagrams, use ASCII art:

```
+---------------+       +---------------+
|   Component A |------>|   Component B |
+---------------+       +---------------+
```

For more complex diagrams, use Mermaid syntax:

```markdown
​```mermaid
graph LR
    A[EC2 Instance] --> B[Application Load Balancer]
    B --> C[Auto Scaling Group]
    C --> D[RDS Database]
​```
```

- Keep diagrams simple and focused on the key components
- Include a legend if using multiple shapes or colors
- Ensure diagrams render correctly in GitHub markdown

## File Organization

- Place lab guides in their respective laboratory directories
- Name files consistently: `lab-guide.md` for all lab guides
- Use `README.md` for module-level documentation
- Store common resources (images, templates) in a central location

## Best Practices

### Step-by-Step Instructions

- Break complex procedures into numbered steps
- Begin each step with an action verb (e.g., "Create", "Configure", "Deploy")
- Include verification steps after important actions
- Indicate expected wait times for resource creation
- Include expected outcomes or outputs

### Code Examples

- Provide complete, working examples
- Include comments to explain complex parts
- Show both the command and expected output
- Use placeholder text for user-specific values

### Troubleshooting Sections

- Organize by common issue types
- Include clear problem descriptions
- Provide step-by-step solutions
- Include commands for diagnosing issues
- Link to relevant AWS documentation

### Cost Information

- Be transparent about which resources incur charges
- Indicate free tier eligibility
- Provide estimated cost ranges
- Include thorough cleanup instructions

## Document Review Process

Before publishing any documentation:

1. Perform a technical accuracy review
2. Check for formatting consistency
3. Validate all links
4. Conduct a spelling and grammar check
5. Test all commands and procedures
6. Verify that all images and diagrams display correctly

## Example Snippets

### Example Step Format

```markdown
### Step 2: Create an S3 Bucket

1. **Open the S3 Console:**
   Navigate to the AWS Management Console and search for "S3" in the services search bar.

2. **Create a new bucket:**
   Click the "Create bucket" button and enter the following details:
   - Bucket name: `<your-unique-bucket-name>`
   - Region: US East (N. Virginia)
   - Leave all other settings as default

3. **Verify bucket creation:**
   ```bash
   aws s3 ls | grep <your-unique-bucket-name>
   ```
   
   You should see your bucket name in the output.
```

### Example Troubleshooting Format

```markdown
## Troubleshooting Guide

### Common Issues and Solutions

1. **"Access Denied" when creating resources:**
   - Verify your IAM user has the correct permissions
   - Check if you're in the correct AWS account
   - Ensure you're in the specified region for the lab

2. **CloudFormation stack creation fails:**
   - Check the "Events" tab in the CloudFormation console for specific error messages
   - Verify that the service quotas for your account allow creating the resources
   - Run the following command to get detailed error information:
     ```bash
     aws cloudformation describe-stack-events --stack-name <stack-name> --query "StackEvents[?ResourceStatus=='CREATE_FAILED']"
     ```
```

### Example Cost Information Format

```markdown
## Resources Created

This lab creates the following AWS resources:

### Compute
- **EC2 Instance**: t2.micro instance (Free Tier eligible)
- **Lambda Function**: 128MB memory, avg. 500ms execution time (Free Tier eligible)

### Storage
- **S3 Bucket**: Less than 1GB storage (Free Tier eligible)
- **EBS Volume**: 8GB gp2 volume (Not Free Tier eligible)

### Networking
- **Elastic IP**: One static IP address (Not Free Tier eligible when not attached to a running instance)

### Estimated Costs
- EC2: $0.00/day (Free Tier) or ~$0.25/day (non-Free Tier)
- S3: $0.00/day (Free Tier) or ~$0.03/day (non-Free Tier)
- EBS: ~$0.80/month
- Elastic IP: $0.00/day (when attached to running instance) or ~$0.31/day (when not attached)
- **Total estimated cost**: $0.00-$1.00/day (mostly Free Tier eligible)
```