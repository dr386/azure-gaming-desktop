variable "admin_username" {
  description = "Administrator username for the virtual machines"
  type        = string
  default     = "adminuser"
}

variable "admin_password" {
  description = "Administrator password for the virtual machines"
  type        = string
  default     = "AdminUser12345!"
  sensitive   = true
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "cloud-gaming-rg" 
}

variable "location" {
  description = "Location for all resources"
  type        = string
  default     = "westus2"
}