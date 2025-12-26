resource "aws_ecr_repository" "repos" {
  for_each = var.repository_names
  name     = each.key
  
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}
