variable "aws_region" {
  type        = string
  default     = "ap-northeast-1"
  description = "Region for testing scanners (DO NOT APPLY)"
}

# ダミー値。apply禁止だが、validate通るように残す
variable "db_username" {
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  type        = string
  default     = "P@ssw0rd123!"
  sensitive   = true
}
