output "apigee_developer_key" {
  description = "The developer key for API requests"
  value       = random_string.consumer_key.result
  sensitive   = true
}
