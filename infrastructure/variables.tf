variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "real-estate-cluster"
}

variable "services" {
  description = "List of service names for ECR repositories"
  type        = list(string)
  default = [
    "user-service",
    "property-service",
    "booking-service",
    "payment-service",
    "notification-service",
    "reclamation-service",
    "blockchain-service",
    "pricing-api",      # ai-service
    "api-gateway",
    "frontend"
  ]
}
