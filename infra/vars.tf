variable "instance_type" {
  default = "t3.micro"
}

variable "path_to_ssh_public_key" {
  default = "~/.ssh/github_sdo_key.pub"
}
