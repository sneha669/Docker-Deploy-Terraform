# terraform Block
terraform {
  required_version = "~>1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3.0"
    }
  }
}

# Provider Block
provider "aws" {
  region = "us-east-1"

}

# ECR Repo
resource "aws_ecr_repository" "my-ecr-repo" {
  name = "my-ecr-repo"
}

# ECS Cluster
resource "aws_ecs_cluster" "demo-app-cluster" {
  name = "demo-app-cluster"
}

# Task Definition
resource "aws_ecs_task_definition" "my-ecr-repo" {
  family                   = "my-ecr-repo"
  container_definitions    = <<DEFINITION
    [
    {  
        "name": "app-first-task",
        "image": "${aws_ecr_repository.my-ecr-repo.repository_url}",
        "essential": true,
        "portMappings": [
        {
        "containerPort": 8000,
        "hostPort": 8000
        }
      ],
    "memory": 512,
    "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # use Fargate as the launch type
  network_mode             = "awsvpc"    # add the AWS VPN network mode as this is required for Fargate
  memory                   = 512         # Specify the memory the container requires
  cpu                      = 256         # Specify the CPU the container requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}


# IAM Role
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# VPC

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-east-1b"
}


# Load Balancer

resource "aws_alb" "demo-app-alb" {
  name               = "demo-app-alb" #load balancer name
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}"
  ]
  # security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}


# Security Group for load balancer

resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic in from all sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Load Bakancer attaching with default vpc

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id # default VPC
}

resource "aws_lb_listener" "demo-app-alb" {
  load_balancer_arn = aws_alb.demo-app-alb.arn #  
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn # target group
  }
}



# ECS Service

resource "aws_ecs_service" "demo-app-cluster" {
  name            = "demo-app-cluster"
  cluster         = aws_ecs_cluster.demo-app-cluster.id                                                # Reference the created Cluster
  task_definition = aws_ecs_task_definition.my-ecr-repo.arn
 # Reference the task that the service will spin up
  launch_type     = "FARGATE"
  desired_count   = 3 # Set up the number of containers to 3

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn # Reference the target group
    container_name   = "app-first-task"
    container_port   = 8000 # Specify the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}"]
    assign_public_ip = true                                                # Provide the containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Set up the security group
  }
}


# traffic from load balancer
resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Log the load balancer app URL
output "app_url" {
  value = aws_alb.demo-app-alb.dns_name
}














