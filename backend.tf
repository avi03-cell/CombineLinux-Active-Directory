terraform {
  backend "s3" {
    bucket  = "state-bucket-34"
    key     = "aws-project/dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
