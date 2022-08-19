#variables.tf
#test

variable "access_key"{
    description = "aws access key"
    type = string
    sensitive = true
}

variable "secret_access_key"{
    description = "aws secret access key"
    type = string
    sensitive = true
}
#variables
variable "subnet_prefix" {
  description = "cidr block for the subnet"
  
}