output "name" {
  value       = local.name
  description = "The generated resource name following the naming standard."
}

output "tags" {
  value       = merge(local.standard_tags, var.tags)
  description = "Merged map of standard tags and any additional tags provided."
}
