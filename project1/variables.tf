variable "instance_name" {
  description = "Value of the EC2 instance's Name tag."
  type        = string
  default     = "project1-ec2-instance1"
}

variable "instance_type" {
  description = "The EC2 instance's type."
  type        = string
  default     = "t2.micro"
}
