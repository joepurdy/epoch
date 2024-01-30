provider "aws" {
  region = "us-west-2"
}

resource "aws_ecr_repository" "epoch_api" {
  name = "epoch-api"
}

resource "aws_ecr_lifecycle_policy" "epoch_api_policy" {
  repository = aws_ecr_repository.epoch_api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
    }]
  })
}

resource "aws_ecs_cluster" "epoch_cluster" {
  name = "epoch-cluster"
}
