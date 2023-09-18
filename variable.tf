################################################################################
# Input variables for the main.tf file
################################################################################

variable "environment" {
  description = "Working application environment eg: dev, stg, prd"
  type        = string
  default     = ""
}

variable "application" {
  description = "Name of the application"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Name to be used on all the resources as identifier"
  type        = string
  default     = ""
}

variable "region" {
  description = "Region be used for all the resources"
  type        = string
  default     = "us-east-2"
}

variable "github_repo_owner" {
  description = "Name of the github repo owner"
  type        = string
}

variable "github_user_repo_name" {
  description = "Name of the order repository"
  type        = string
}

variable "github_user_branch" {
  description = "Name of the branch of the order repository"
  type        = string
  default     = "main"
}

variable "github_product_repo_name" {
  description = "Name of the order repository"
  type        = string
}

variable "github_product_branch" {
  description = "Name of the branch of the order repository"
  type        = string
  default     = "main"
}

variable "github_order_repo_name" {
  description = "Name of the order repository"
  type        = string
}

variable "github_order_branch" {
  description = "Name of the branch of the order repository"
  type        = string
  default     = "main"
}
