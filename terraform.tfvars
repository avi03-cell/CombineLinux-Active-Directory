aws_region = "ap-south-1"

project_name = "Active-Directory"

availability_zone = "ap-south-1a"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidr = "10.0.1.0/24"

private_subnet_cidr = "10.0.11.0/24"

allowed_rdp_cidr = [
  "223.181.22.162/32",
  "192.48.82.228/32"
]

key_pair_name = "Active Directory-Keypair"

windows_server_ami = "ami-05fdee25803e36cbc"

windows_client_ami = "ami-05fdee25803e36cbc"

###########################################################
# Bastion Host
###########################################################

bastion_ami           = "ami-05fdee25803e36cbc"
bastion_instance_type = "t3.medium"

