terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "webapp-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "webapp-vpc"
  }
}

data "aws_availability_zones" "available" {
    state = "available"
  
}

resource "aws_subnet" "public_1" {
    vpc_id = aws_vpc.webapp-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true

    tags = {
      Name = "public-subnet-1"
    }
    depends_on = [aws_vpc.webapp-vpc] 
}

resource "aws_subnet" "public_2" {
    vpc_id = aws_vpc.webapp-vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = true

    tags = {
      Name = "public-subnet-2"
    }
  depends_on = [aws_vpc.webapp-vpc] 
}
resource "aws_internet_gateway" "aws_internet_gateway" {
    vpc_id =aws_vpc.webapp-vpc.id
    tags = {
      Name = "webapp-internet-gateway"
    }
 depends_on = [aws_vpc.webapp-vpc] 
}

resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.webapp-vpc.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id =aws_internet_gateway.aws_internet_gateway.id
}
    tags = {
      Name = "public-route-table"
    }
    depends_on = [aws_vpc.webapp-vpc, aws_internet_gateway.aws_internet_gateway]
}

resource "aws_route_table_association" "public_subnet_1_association" {
    subnet_id      = aws_subnet.public_1.id
    route_table_id = aws_route_table.public_route_table.id
    depends_on = [aws_subnet.public_1, aws_route_table.public_route_table]

  
}
resource "aws_route_table_association" "public_subnet_2_association" {
    subnet_id      = aws_subnet.public_2.id
    route_table_id = aws_route_table.public_route_table.id
    depends_on = [aws_subnet.public_2, aws_route_table.public_route_table]
  
}
resource "aws_subnet" "private_1" {
    vpc_id = aws_vpc.webapp-vpc.id
    cidr_block = "10.0.3.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]

    tags = {
      Name = "private-subnet-1"
    }
    depends_on = [aws_vpc.webapp-vpc] 
}
resource "aws_route_table" "aws_private_route_table" {
    vpc_id = aws_vpc.webapp-vpc.id
      route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.aws_nat_gateway.id
    }
    tags = {
      Name = "private-route-table"
    }

      depends_on = [aws_vpc.webapp-vpc]
}
resource "aws_route_table_association" "private_subnet_1_association" {
    subnet_id      = aws_subnet.private_1.id
    route_table_id = aws_route_table.aws_private_route_table.id
    
  
}
resource "aws_eip" "IPaddress" {
  tags = {
    Name = "webapp-eip"
  }

}

resource "aws_nat_gateway" "aws_nat_gateway" {
  allocation_id = aws_eip.IPaddress.allocation_id
  subnet_id     = aws_subnet.public_1.id
  

  tags = {
    Name = "webapp-nat-gateway"
  }
  depends_on = [aws_subnet.public_1, aws_eip.IPaddress]
  
}
resource "tls_private_key" "webapp_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "webapp_key_pair" {
  key_name   = "webapp-key-pair" # Replace with your desired key pair name
  public_key = tls_private_key.webapp_key_pair.public_key_openssh

  tags = {
    Name = "webapp-key-pair"
  }
    depends_on = [tls_private_key.webapp_key_pair]
}

output "private_key_pem" {
    value = tls_private_key.webapp_key_pair.private_key_pem
    description = "value of the private key in PEM format. Save this securely as it will not be shown again."
    sensitive = true
}

resource "aws_security_group" "webapp_security_group" {
  name        = "webapp-security-group"
  description = "Security group for web application configured in Application Load Balancer"
  vpc_id      = aws_vpc.webapp-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere, consider restricting this in production
  
}
ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    security_groups = [aws_security_group.alb_security_group.id] #Allow HTTP from anywhere
}
egress  {
    from_port = 0
    to_port   = 0
    protocol  = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
    }
depends_on = [ aws_vpc.webapp-vpc,aws_security_group.alb_security_group ]
}


resource "aws_instance" "webapp_instance" {
  ami           = "ami-0de716d6197524dd9" # Example AMI, replace with a valid one for your region
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_1.id
  associate_public_ip_address = true # Enable public IP for the instance
  key_name = "webapp-key-pair" # Replace with your key pair nameter
  vpc_security_group_ids = [aws_security_group.webapp_security_group.id]
 user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "Hello, World! Welcome to EC2 Instance" > /var/www/html/index.html
              EOF
  tags = {
    Name = "webapp-instance"
  }

  depends_on = [aws_subnet.private_1, aws_internet_gateway.aws_internet_gateway,aws_security_group.webapp_security_group]
}

resource "aws_security_group" "alb_security_group" {
  name = "alb-security-group"
  description = "Security group for Application Load Balancer"
  vpc_id =aws_vpc.webapp-vpc.id
  ingress {
    description = "Allow HTTP traffic from anywhere"
    from_port = 80
    to_port = 80
    protocol ="tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open HTTP to the internet
  }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1" # Allow all outbound traffic
        cidr_blocks = ["0.0.0.0/0"]
}
    tags = {
        Name = "alb-security-group"
    }
    depends_on = [aws_vpc.webapp-vpc]
}

resource "aws_alb" "webapp_alb" {
  name               = "webapp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

 
 enable_deletion_protection = false

  tags = {
    Name = "webapp-alb"
  }
  depends_on = [aws_subnet.public_1, aws_subnet.public_2, aws_security_group.webapp_security_group, aws_vpc.webapp-vpc, aws_internet_gateway.aws_internet_gateway]
}

resource "aws_alb_target_group" "webapp_target_group" {
  name     = "webapp-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.webapp-vpc.id
  

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "webapp-target-group"
  }
  depends_on = [ aws_vpc.webapp-vpc ]
}

resource "aws_alb_listener" "webapp_listener" {
 load_balancer_arn = aws_alb.webapp_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.webapp_target_group.arn
    
  }

  tags = {
    Name = "webapp-listener"
  }
    depends_on = [aws_alb.webapp_alb, aws_alb_target_group.webapp_target_group]
}

resource "aws_alb_target_group_attachment" "aws_register_instance" {
    target_group_arn=aws_alb_target_group.webapp_target_group.arn
    target_id=aws_instance.webapp_instance.id
    port = 80
    depends_on = [ aws_alb.webapp_alb,aws_alb_target_group.webapp_target_group, aws_instance.webapp_instance, aws_alb_listener.webapp_listener]
  
}

resource "aws_launch_template" "webapp_launch_template" {
    name_prefix = "webapp-launch-template"

    image_id = "ami-0de716d6197524dd9"
    instance_type ="t2.micro"

    key_name ="webapp-key-pair" # Replace with your key pair name
   
   network_interfaces {
    security_groups = [aws_security_group.webapp_security_group.id]
    associate_public_ip_address = false
     subnet_id=aws_subnet.private_1.id
     }

     user_data =base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "Hello, World! Welcome to EC2 Instance" > /var/www/html/index.html
              EOF
     )
     tag_specifications {
       resource_type ="instance"
       tags = {
     Name = "webapp-launch-template"
   } 
 }
}

resource "aws_autoscaling_group" "webapp_autoscaling_group" {
  name                      = "webapp-autoscaling-group"
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 3

  launch_template {
    id=aws_launch_template.webapp_launch_template.id
    version = "$Latest"
  }
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.private_1.id,aws_subnet.public_1.id,aws_subnet.public_2.id]
  target_group_arns = [aws_alb_target_group.webapp_target_group.arn]


  timeouts {
    delete = "15m"
  }
tag {
  key = "Name"
  value = "webapp-autoscaling-group"
  propagate_at_launch = true
}

lifecycle {
  create_before_destroy = true
}

}

resource "aws_autoscaling_policy" "webapp_autoscaling_policy" {
    name = "webapp-autoscaling-policy"
    policy_type = "TargetTrackingScaling"
    autoscaling_group_name = aws_autoscaling_group.webapp_autoscaling_group.name
target_tracking_configuration {
 target_value = 50.0
 
 predefined_metric_specification {
   predefined_metric_type = "ASGAverageCPUUtilization"
 }
 }
  depends_on = [aws_autoscaling_group.webapp_autoscaling_group, aws_alb_target_group.webapp_target_group] 
}

resource "aws_s3_bucket" "terraform_state_lock" {
  bucket = "terraform-state-lock-bucket-for-webapp"
 

  tags = {
    Name        = "terraform-state-lock-bucket"
  }
}
resource "aws_s3_bucket_versioning" "enable_versioning" {
  bucket = aws_s3_bucket.terraform_state_lock.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_state_lock_table" {
    name = "terraform-state-lock-table"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"

    attribute {
      
      name = "LockID"
      type = "S"
    }
  tags = {
    Name = "terraform-state-lock-table"
  }
}
