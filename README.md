AWS Web Application Deployment using Terraform:

This project demonstrates deploying a scalable, highly available web application on AWS using Terraform as Infrastructure as Code (IaC).

It provisions AWS networking, compute, load balancing, and auto scaling resources, with remote state management in S3 and state locking via DynamoDB.

---------------------------------------------------------------------------------------------------------------------------------------------------------------
Architecture
AWS Services Used:

1. VPC with public and private subnets across multiple Availability Zones (us-east-1a & us-east-1b)

2. Application Load Balancer (ALB) for traffic distribution

3. Auto Scaling Group (ASG) with Launch Template

4. EC2 instances running the web application

5. Security Groups for traffic control

6. S3 bucket for Terraform remote state

7. DynamoDB table for state locking

------------------------------------------------------------------------------------------------------------------------------------------------------------------
Features
1. Infrastructure provisioning using Terraform

2. High availability with multiple AZs

3. Auto scaling based on CPU utilization (>50%)

4. Secure state storage in S3 with DynamoDB locking

5. Modular and reusable Terraform code

------------------------------------------------------------------------------------------------------------------------------------------------------------------

Deployment Steps
bash
Copy
Edit
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply

-----------------------------------------------------------------------------------------------------------------------------------------------------------------
Repository Structure

├── main.tf              # Main Terraform configuration

├── variables.tf         # Input variables

├── outputs.tf           # Outputs after deployment

├── provider.tf          # AWS provider configuration

└── README.md            # Project documentation

------------------------------------------------------------------------------------------------------------------------------------------------------------------
Backend Configuration Example


terraform {

  backend "s3" {
  
	bucket         = "terraform-state-lock-bucket-for-webapp"
   
    key            = "terraform.tfstate"
    
    region         = "us-east-1"
    
    dynamodb_table = "terraform-state-lock-table"
    
    encrypt        = true
    
  }
  
}

Screenshots

-------------------------------------------------------------------------------------------------------------------------------------------------------------------

Key Learnings

1. How to design AWS networking with VPC & subnets for public/private architecture

2. Implementing load balancing & auto scaling using ALB and ASG

3. Managing Terraform remote state securely with S3 and DynamoDB

4. Writing clean, reusable Terraform code for AWS provisioning**
