variable "aws_region" {
  description = "Primary AWS region for the S3 bucket and most resources."
  type        = string
  default     = "eu-central-1"
}

variable "domain" {
  description = "Primary domain (apex). The www. variant is added automatically."
  type        = string
  default     = "offsetprint.eu"
}

variable "bucket_name" {
  description = "S3 bucket name (must be globally unique)."
  type        = string
  default     = "offsetprint-site-prod"
}

variable "github_repo" {
  description = "GitHub repository in <owner>/<name> form for OIDC trust scoping."
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to assume the deploy role."
  type        = string
  default     = "main"
}

variable "budget_email" {
  description = "Email address that receives AWS Budget alerts."
  type        = string
  default     = "office@offsetprint.eu"
}
