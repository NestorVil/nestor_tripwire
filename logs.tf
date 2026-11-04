resource "aws_cloudwatch_log_group" "laminar" {
  for_each = toset(["frontend", "app-server", "data-box"])

  name              = "/${var.name_prefix}/${each.key}"
  retention_in_days = 14
}
