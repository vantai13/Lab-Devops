variable "project_name" { type = string }
variable "vpc_id"        { type = string }


variable "my_ip" {
  description = "IP cua ban de SSH vao Bastion Host (format: x.x.x.x/32)"
  type        = string
}
