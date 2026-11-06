variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "tf_state_bucket" {
  type    = string
  default = "northbridge-terraform-state-dev"
}