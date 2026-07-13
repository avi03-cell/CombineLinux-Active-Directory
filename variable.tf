###############################################
# AWS Configuration
###############################################

variable "aws_region" {
  description = "AWS Region"
  type        = string
}


variable "availability_zone" {
  description = "Availability Zone"
  type        = string
  default     = ""
}


###############################################
# Project Configuration
###############################################

variable "project_name" {

  description = "Project Name"

  type = string

}


variable "environment" {

  description = "Environment"

  type = string

  default = "dev"

}


###############################################
# Networking
###############################################

variable "vpc_cidr" {

  description = "VPC CIDR Block"

  type = string

}


variable "public_subnet_1_cidr" {

  description = "Public Subnet 1 CIDR"

  type = string

}


variable "public_subnet_2_cidr" {

  description = "Public Subnet 2 CIDR"

  type = string

}


variable "private_subnet_1_cidr" {

  description = "Private Subnet 1 CIDR"

  type = string

}


variable "private_subnet_2_cidr" {

  description = "Private Subnet 2 CIDR"

  type = string

}



###############################################
# Linux EC2 Configuration
###############################################

variable "ami_id" {

  description = "Linux AMI ID"

  type = string

}


variable "instance_type" {

  description = "EC2 Instance Type"

  type = string

  default = "t3.micro"

}


variable "key_pair_name" {

  description = "EC2 Key Pair"

  type = string

}



###############################################
# SSH Access
###############################################

variable "allowed_ssh_cidr" {

  description = "Allowed SSH IP"

  type = list(string)

}



###############################################
# PostgreSQL
###############################################

variable "postgres_db" {

  description = "Database Name"

  type = string

}


variable "postgres_user" {

  description = "Database User"

  type = string

}


variable "postgres_password" {

  description = "Database Password"

  type = string

  sensitive = true

}



###############################################
# Website
###############################################

variable "website_title" {

  description = "Website Title"

  type = string

}


variable "website_heading" {

  description = "Website Heading"

  type = string

}



###############################################
# Tags
###############################################

variable "owner" {

  description = "Owner"

  type = string

}


variable "cost_center" {

  description = "Cost Center"

  type = string

}


variable "tags" {

  description = "Additional Tags"

  type = map(string)

  default = {}

}



###############################################
# Active Directory
###############################################

variable "windows_server_ami" {

  description = "Windows Server AMI"

  type = string

}


variable "windows_client_ami" {

  description = "Windows Client AMI"

  type = string

}



variable "allowed_rdp_cidr" {

  description = "Allowed RDP IPs"

  type = list(string)

}



###############################################
# Bastion Host
###############################################

variable "bastion_ami" {

  description = "Bastion Host AMI"

  type = string

}


variable "bastion_instance_type" {

  description = "Bastion Instance Type"

  type = string

  default = "t3.medium"

}