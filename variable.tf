variable "region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "app_name" {
  default = "demo-app"
}

variable "ecr_image_url" {
  description = "ECR image URL with tag"
  type        = string
}
