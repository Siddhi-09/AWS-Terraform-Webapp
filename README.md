# AWS Web Application Infrastructure using Terraform

## Overview
This project provisions a highly available 3-tier architecture in AWS using Terraform. 
It includes:
- VPC with public & private subnets across multiple AZs
- Internet Gateway & NAT Gateway
- Application Load Balancer
- Auto Scaling Group with EC2 Launch Template
- Remote state storage in S3 with DynamoDB locking



## Deployment Steps
1. Clone the repo
2. Configure AWS CLI with IAM credentials
3. Run:
```bash
terraform init
terraform plan
terraform apply
yaml
Copy
Edit