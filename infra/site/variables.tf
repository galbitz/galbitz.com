variable "region" {
  type    = string
  default = "us-east-1"
}
variable "domain_name" {
  default = "galbitz.com"
}

variable "subject_names" {
    default = ["galbitz.com", "www.galbitz.com"]
}