
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
# VPC
###########################################################

resource "aws_vpc" "main" {

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

###########################################################
# DHCP Options for Active Directory
###########################################################

resource "aws_vpc_dhcp_options" "ad_dns" {

  domain_name = "gt.local"

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
# Internet Gateway
###########################################################

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}
###########################################################
# Public Subnet
###########################################################

resource "aws_subnet" "public_1" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-1"
  }
}
###########################################################
# Private Subnet
###########################################################

resource "aws_subnet" "private_1" {

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.project_name}-private-1"
  }
}
###########################################################
# Elastic IP
###########################################################

resource "aws_eip" "nat" {

  domain = "vpc"

  depends_on = [
    aws_internet_gateway.igw
  ]
}
###########################################################
# NAT Gateway
###########################################################

resource "aws_nat_gateway" "nat" {

  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
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

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}
###########################################################
# Private Route Table
###########################################################

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.main.id

  route {

    cidr_block     = "0.0.0.0/0"

    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}
###########################################################
# Public Route Association
###########################################################

resource "aws_route_table_association" "public" {

  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

###########################################################
# Private Route Association
###########################################################

resource "aws_route_table_association" "private" {

  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}
###########################################################
# Locals
###########################################################

locals {

  common_tags = {

    Project = var.project_name

    ManagedBy = "Terraform"
  }
}






resource "aws_iam_role" "ec2_role" {

  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}




resource "aws_iam_role_policy_attachment" "ssm" {

  role       = aws_iam_role.ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}



resource "aws_iam_instance_profile" "ec2_profile" {

  name = "${var.project_name}-instance-profile"

  role = aws_iam_role.ec2_role.name
}
###########################################################
# Active Directory Security Group
###########################################################

resource "aws_security_group" "ad_sg" {

  name = "${var.project_name}-ad-sg"

  description = "Security group for Active Directory lab"

  vpc_id = aws_vpc.main.id


  #########################################################
  # RDP From Admin Machine
  #########################################################

 ingress {
  description = "RDP from Bastion"

  from_port = 3389
  to_port   = 3389
  protocol  = "tcp"

  security_groups = [
    aws_security_group.bastion_sg.id
  ]
}


  #########################################################
  # AD Communication Between DC and Client
  #########################################################

ingress {

  description = "Active Directory Internal Traffic"

  from_port = 0

  to_port = 0

  protocol = "-1"

  self = true

}


  #########################################################
  # DNS TCP
  #########################################################

  ingress {

    description = "DNS TCP"

    from_port = 53

    to_port = 53

    protocol = "tcp"

    self = true
  }


  #########################################################
  # DNS UDP
  #########################################################

  ingress {

    description = "DNS UDP"

    from_port = 53

    to_port = 53

    protocol = "udp"

    self = true
  }



  #########################################################
  # Outbound
  #########################################################

  egress {

    from_port = 0

    to_port = 0

    protocol = "-1"


    cidr_blocks = [

      "0.0.0.0/0"

    ]
  }


  tags = merge(

    local.common_tags,

    {

      Name="${var.project_name}-ad-sg"

    }

  )

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

  vpc_security_group_ids = [
    aws_security_group.bastion_sg.id
  ]

  tags = {
    Name = "Bastion"
  }
}
