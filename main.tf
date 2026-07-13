###########################################################
# Terraform & AWS Provider
###########################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

###########################################################
# Availability Zones
###########################################################

data "aws_availability_zones" "available" {
  state = "available"
}

###########################################################
# Local Values
###########################################################

locals {

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    },
    var.tags
  )

  az1 = data.aws_availability_zones.available.names[0]
  az2 = data.aws_availability_zones.available.names[1]
}

###########################################################
# VPC
###########################################################

resource "aws_vpc" "main" {

  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

###########################################################
# Internet Gateway
###########################################################

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}

###########################################################
# Public Subnet 1
###########################################################

resource "aws_subnet" "public_1" {

  vpc_id = aws_vpc.main.id

  cidr_block = var.public_subnet_1_cidr

  availability_zone = local.az1

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-public-1"
    }
  )
}

###########################################################
# Public Subnet 2
###########################################################

resource "aws_subnet" "public_2" {

  vpc_id = aws_vpc.main.id

  cidr_block = var.public_subnet_2_cidr

  availability_zone = local.az2

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-public-2"
    }
  )
}

###########################################################
# Private Subnet 1
###########################################################

resource "aws_subnet" "private_1" {

  vpc_id = aws_vpc.main.id

  cidr_block = var.private_subnet_1_cidr

  availability_zone = local.az1

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-1"
    }
  )
}

###########################################################
# Private Subnet 2
###########################################################

resource "aws_subnet" "private_2" {

  vpc_id = aws_vpc.main.id

  cidr_block = var.private_subnet_2_cidr

  availability_zone = local.az2

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-2"
    }
  )
}
###########################################################
# Elastic IP for NAT Gateway
###########################################################

resource "aws_eip" "nat" {

  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-nat-eip"
    }
  )
}

###########################################################
# NAT Gateway
###########################################################

resource "aws_nat_gateway" "nat" {

  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public_1.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-nat"
    }
  )
}

###########################################################
# Public Route Table
###########################################################

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-public-rt"
    }
  )
}

###########################################################
# Private Route Table
###########################################################

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.main.id

  route {

    cidr_block = "0.0.0.0/0"

    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-rt"
    }
  )
}

###########################################################
# Public Route Table Association - Public Subnet 1
###########################################################

resource "aws_route_table_association" "public_1" {

  subnet_id = aws_subnet.public_1.id

  route_table_id = aws_route_table.public.id
}

###########################################################
# Public Route Table Association - Public Subnet 2
###########################################################

resource "aws_route_table_association" "public_2" {

  subnet_id = aws_subnet.public_2.id

  route_table_id = aws_route_table.public.id
}

###########################################################
# Private Route Table Association - Private Subnet 1
###########################################################

resource "aws_route_table_association" "private_1" {

  subnet_id = aws_subnet.private_1.id

  route_table_id = aws_route_table.private.id
}

###########################################################
# Private Route Table Association - Private Subnet 2
###########################################################

resource "aws_route_table_association" "private_2" {

  subnet_id = aws_subnet.private_2.id

  route_table_id = aws_route_table.private.id
}
###########################################################
# Security Group - Application Load Balancer
###########################################################

resource "aws_security_group" "alb_sg" {

  name        = "${var.project_name}-alb-sg"
  description = "Security Group for Application Load Balancer"

  vpc_id = aws_vpc.main.id

  ingress {

    description = "HTTP"

    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {

    description = "HTTPS"

    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {

    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alb-sg"
    }
  )
}

###########################################################
# Security Group - EC2
###########################################################

resource "aws_security_group" "ec2_sg" {

  name        = "${var.project_name}-ec2-sg"
  description = "Security Group for Private EC2"

  vpc_id = aws_vpc.main.id

  #####################################################
  # HTTP ONLY FROM ALB
  #####################################################

  ingress {

    description = "HTTP from ALB"

    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    security_groups = [
      aws_security_group.alb_sg.id
    ]
  }

  #####################################################
  # SSH FROM YOUR IP
  #####################################################

  ingress {

    description = "SSH"

    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = var.allowed_ssh_cidr
  }

  #####################################################
  # PostgreSQL (Optional)
  #####################################################

  ingress {

    description = "PostgreSQL"

    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"

    self = true
  }

  #####################################################

  egress {

    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ec2-sg"
    }
  )
}
###########################################################
# IAM Role for EC2
###########################################################

resource "aws_iam_role" "ec2_role" {

  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ec2-role"
    }
  )
}

###########################################################
# Attach AmazonSSMManagedInstanceCore Policy
###########################################################

resource "aws_iam_role_policy_attachment" "ssm" {

  role = aws_iam_role.ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

###########################################################
#  CloudWatch Agent Policy
###########################################################

resource "aws_iam_role_policy_attachment" "cloudwatch" {

  role = aws_iam_role.ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

###########################################################
# IAM Instance Profile
###########################################################

resource "aws_iam_instance_profile" "ec2_profile" {

  name = "${var.project_name}-instance-profile"

  role = aws_iam_role.ec2_role.name
}
###########################################################
# EC2 Instance
###########################################################

resource "aws_instance" "webserver" {

  ami = var.ami_id

  instance_type = var.instance_type

  subnet_id = aws_subnet.private_1.id

  private_ip = "10.0.11.30"

  key_name = var.key_pair_name


  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id
  ]


  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name


  associate_public_ip_address = false


  user_data = templatefile("${path.module}/userdata.sh", {

    postgres_db       = var.postgres_db
    postgres_user     = var.postgres_user
    postgres_password = var.postgres_password

    website_title     = var.website_title
    website_heading   = var.website_heading
  })


  root_block_device {

    volume_size = 20

    volume_type = "gp3"

    delete_on_termination = true
  }


  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-Linux"
    }
  )


  depends_on = [
    aws_nat_gateway.nat
  ]

}

###########################################################
# Application Load Balancer
###########################################################

resource "aws_lb" "alb" {

  name = "${var.project_name}-alb"

  internal = false

  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb_sg.id
  ]

  #########################################################
  # ALB MUST BE IN TWO PUBLIC SUBNETS
  #########################################################

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  enable_deletion_protection = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alb"
    }
  )
}

###########################################################
# Target Group
###########################################################

resource "aws_lb_target_group" "web" {

  name = "${var.project_name}-tg"

  port = 80

  protocol = "HTTP"

  vpc_id = aws_vpc.main.id

  target_type = "instance"

  #########################################################
  # Health Check
  #########################################################

  health_check {

    enabled = true

    path = "/"

    protocol = "HTTP"

    matcher = "200"

    interval = 30

    timeout = 5

    healthy_threshold = 2

    unhealthy_threshold = 2
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-tg"
    }
  )
}

###########################################################
# Register EC2 with Target Group
###########################################################

resource "aws_lb_target_group_attachment" "webserver" {

  target_group_arn = aws_lb_target_group.web.arn

  target_id = aws_instance.webserver.id

  port = 80
}

###########################################################
# HTTP Listener
###########################################################

resource "aws_lb_listener" "http" {

  load_balancer_arn = aws_lb.alb.arn

  port = 80

  protocol = "HTTP"

  default_action {

    type = "forward"

    target_group_arn = aws_lb_target_group.web.arn
  }
}
###########################################################
# Outputs
###########################################################

###########################################################
# VPC
###########################################################

output "vpc_id" {

  description = "VPC ID"

  value = aws_vpc.main.id
}

###########################################################
# Public Subnets
###########################################################

output "public_subnet_1_id" {

  description = "Public Subnet 1 ID"

  value = aws_subnet.public_1.id
}

output "public_subnet_2_id" {

  description = "Public Subnet 2 ID"

  value = aws_subnet.public_2.id
}

###########################################################
# Private Subnets
###########################################################

output "private_subnet_1_id" {

  description = "Private Subnet 1 ID"

  value = aws_subnet.private_1.id
}

output "private_subnet_2_id" {

  description = "Private Subnet 2 ID"

  value = aws_subnet.private_2.id
}

###########################################################
# NAT Gateway
###########################################################

output "nat_gateway_id" {

  description = "NAT Gateway ID"

  value = aws_nat_gateway.nat.id
}

###########################################################
# EC2 Instance
###########################################################

output "ec2_instance_id" {

  description = "EC2 Instance ID"

  value = aws_instance.webserver.id
}

output "private_ec2_private_ip" {

  description = "Private IP of EC2"

  value = aws_instance.webserver.private_ip
}

###########################################################
# Load Balancer
###########################################################

output "alb_dns_name" {

  description = "Application Load Balancer DNS"

  value = aws_lb.alb.dns_name
}

output "alb_arn" {

  description = "Application Load Balancer ARN"

  value = aws_lb.alb.arn
}

###########################################################
# Target Group
###########################################################

output "target_group_arn" {

  description = "Target Group ARN"

  value = aws_lb_target_group.web.arn
}

###########################################################
# Website URL
###########################################################

output "website_url" {

  description = "Open this URL in your browser"

  value = "http://${aws_lb.alb.dns_name}"
}

###########################################################
# IAM
###########################################################

output "iam_role_name" {

  description = "IAM Role"

  value = aws_iam_role.ec2_role.name
}

output "instance_profile" {

  description = "IAM Instance Profile"

  value = aws_iam_instance_profile.ec2_profile.name
}









###########################################################
# DHCP Options for Active Directory
###########################################################

resource "aws_vpc_dhcp_options" "ad_dns" {

  domain_name = "gtc.local"

  domain_name_servers = [
    "10.0.11.10"
  ]

  tags = {
    Name = "${var.project_name}-ad-dhcp"
  }
}

resource "aws_vpc_dhcp_options_association" "ad_dns" {

  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.ad_dns.id
}









###########################################################
# Active Directory Security Group
###########################################################

resource "aws_security_group" "ad_sg" {

  name = "${var.project_name}-ad-sg"

  description = "Security group for Active Directory lab"

  vpc_id = aws_vpc.main.id


  # Linux to AD
  ingress {

    description = "Linux to AD"

    from_port = 0
    to_port = 65535
    protocol = "tcp"

    security_groups = [
      aws_security_group.ec2_sg.id
    ]
  }


  # RDP from Bastion

  ingress {

    description = "RDP from Bastion"

    from_port = 3389
    to_port   = 3389
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bastion_sg.id
    ]
  }


  # LDAP

  ingress {

    description = "LDAP"

    from_port = 389
    to_port   = 389
    protocol = "tcp"

    security_groups = [
      aws_security_group.ec2_sg.id
    ]
  }


  # LDAPS

  ingress {

    description = "LDAPS"

    from_port = 636
    to_port = 636
    protocol = "tcp"

    security_groups = [
      aws_security_group.ec2_sg.id
    ]
  }


  # Kerberos TCP

  ingress {

    description = "Kerberos TCP"

    from_port = 88
    to_port = 88
    protocol = "tcp"

    security_groups = [
      aws_security_group.ec2_sg.id
    ]
  }


  # Kerberos UDP

  ingress {

    description = "Kerberos UDP"

    from_port = 88
    to_port = 88
    protocol = "udp"

    security_groups = [
      aws_security_group.ec2_sg.id
    ]
  }


  # DNS TCP

  ingress {

    description = "DNS TCP"

    from_port = 53
    to_port = 53
    protocol = "tcp"

    security_groups = [
      aws_security_group.ec2_sg.id
    ]
  }


  # DNS UDP

  ingress {

    description = "DNS UDP"

    from_port = 53
    to_port = 53
    protocol = "udp"

    security_groups = [
      aws_security_group.ec2_sg.id
    ]
  }


  # SMB

  ingress {

    description = "SMB"

    from_port = 445
    to_port = 445
    protocol = "tcp"

    security_groups = [
      aws_security_group.ec2_sg.id
    ]
  }


  # Global Catalog

  ingress {

    description = "Global Catalog"

    from_port = 3268
    to_port = 3268
    protocol = "tcp"

    security_groups = [
      aws_security_group.ec2_sg.id
    ]
  }


  # Outbound

  egress {

    from_port = 0
    to_port = 0
    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]

  }


}
###########################################################
# Windows Domain Controller
###########################################################

resource "aws_instance" "domain_controller" {


  ami = var.windows_server_ami


  instance_type = "t3.medium"


  subnet_id = aws_subnet.private_1.id


  private_ip = "10.0.11.10"


  key_name = var.key_pair_name



  vpc_security_group_ids = [

    aws_security_group.ad_sg.id

  ]



  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name



  associate_public_ip_address = false



  root_block_device {


    volume_size = 80


    volume_type = "gp3"


    delete_on_termination = true


  }



  user_data = <<-EOF

<powershell>


# Rename server

Rename-Computer `

-NewName "DC01" `

-Force



# Install AD DS role

Install-WindowsFeature `

-Name AD-Domain-Services `

-IncludeManagementTools



# Install DNS role

Install-WindowsFeature `

-Name DNS `

-IncludeManagementTools



Restart-Computer -Force


</powershell>

EOF



  tags = merge(

    local.common_tags,

    {

      Name="${var.project_name}-DC01"

    }

  )



  depends_on = [

    aws_nat_gateway.nat

  ]

}
###########################################################
# Windows Client Machine
###########################################################

resource "aws_instance" "windows_client" {


  ami = var.windows_client_ami



  instance_type = "t3.medium"



  subnet_id = aws_subnet.private_1.id



  private_ip = "10.0.11.20"



  key_name = var.key_pair_name



  vpc_security_group_ids = [

    aws_security_group.ad_sg.id

  ]



  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name



  associate_public_ip_address = false



  root_block_device {


    volume_size = 60


    volume_type = "gp3"


  }



  user_data = <<-EOF

<powershell>


Rename-Computer `

-NewName "CLIENT01" `

-Force



Restart-Computer -Force


</powershell>

EOF



  tags = merge(

    local.common_tags,

    {

      Name="${var.project_name}-CLIENT01"

    }

  )



  depends_on = [

    aws_instance.domain_controller

  ]

}

resource "aws_security_group" "bastion_sg" {

  name        = "${var.project_name}-bastion-sg"
  description = "Windows Bastion Host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "RDP from my laptop"

    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"

    cidr_blocks = var.allowed_rdp_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}



resource "aws_instance" "bastion" {

  ami           = var.windows_server_ami
  instance_type = "t3.medium"

  subnet_id = aws_subnet.public_1.id

  associate_public_ip_address = true

  key_name = var.key_pair_name

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name


  vpc_security_group_ids = [
    aws_security_group.bastion_sg.id
  ]


  depends_on = [
    aws_internet_gateway.igw
  ]


  tags = {
    Name = "Bastion"
  }
}

