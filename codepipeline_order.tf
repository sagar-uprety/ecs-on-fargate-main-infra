################################################################################
# Codepipeline for Order Service
################################################################################

#CodePipeline
resource "aws_codepipeline" "lms_ecs_pipeline_order" {
  name       = "order_pipeline"
  role_arn   = aws_iam_role.codepipeline_role.arn
  depends_on = [module.ecs_cluster, module.alb, module.alb_sg, module.order_dynamodb_table, module.order_ecr, module.vpc, module.product_dynamodb_table, module.product_ecr, module.user_dynamodb_table, module.user_ecr]

  artifact_store {
    location = "lms-playground"
    type     = "S3"
  }

  # SOURCE
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = data.aws_ssm_parameter.codestar_connection_ssm.value
        FullRepositoryId = "${var.github_repo_owner}/${var.github_order_repo_name}"
        BranchName       = var.github_order_branch
      }
    }
  }

  # BUILD
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.lms_ecs_build_order.name
      }
    }
  }
  # DEPLOY
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.lms_ecs_apply_order.name
      }
    }
  }
}

# CodeBuild for build
resource "aws_codebuild_project" "lms_ecs_build_order" {
  name         = "order-build"
  description  = "Image Build stage and Terraform planning stage"
  service_role = aws_iam_role.codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-plan.yml"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "REGION"
      value = var.region
    }
  }
}

# CodeBuild for deploy
resource "aws_codebuild_project" "lms_ecs_apply_order" {
  name         = "order-deploy"
  description  = "Terraform applying stage"
  service_role = aws_iam_role.codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-apply.yml"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "REGION"
      value = var.region
    }
  }
}