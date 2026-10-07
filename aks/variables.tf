variable "location" {
  type        = string
  default     = "westus2"
  description = "Azure region for resources"
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "size" {
  type        = string
  default     = "Standard_D2s_v7"
  description = "Size of the virtual machine"
}

variable "postgres_admin_password" {
  type        = string
  sensitive = true
  description = "Password for the PostgreSQL admin user"
}

variable "postgres_admin_username" {
  type        = string
  description = "Username for the PostgreSQL admin user"
}

variable "n8n_encryption_key" {
  type        = string
  sensitive = true
  description = "Encryption key for n8n"
}