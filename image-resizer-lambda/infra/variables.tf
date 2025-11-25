variable "customer_service_client_secret" {
  description = "OAuth client secret for customer service"
  type        = string
  sensitive   = true
}

variable "keycloak_base_url" {
  description = "Keycloak baseurl"
  type        = string
  sensitive   = false
  default     = "http://waitque-alb-1208411922.us-east-1.elb.amazonaws.com"
}

variable "company_service_base_url" {
  description = "company_service baseurl"
  type        = string
  sensitive   = false
  default     = "http://waitque-alb-1208411922.us-east-1.elb.amazonaws.com/2"
}