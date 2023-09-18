resource "aws_codepipeline" "lms_ecs_pipeline_user" {
  name     = "user_pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

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
        ConnectionArn    = "arn:aws:codestar-connections:us-east-1:426857564226:connection/a96d0fa6-04d0-4bac-ab64-988b299a805b" #aws_codestarconnections_connection.ecs-lms-connection.arn
        FullRepositoryId = "${var.github_repo_owner}/${var.github_user_repo_name}"
        BranchName       = var.github_user_branch
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
        ProjectName = aws_codebuild_project.lms_ecs_build_user.name
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
        ProjectName = aws_codebuild_project.lms_ecs_apply_user.name
      }
    }
  }
}

# resource "aws_codestarconnections_connection" "ecs-lms-connection" {
#   name          = "ecs-lms-connection"
#   provider_type = "GitHub"
# }

resource "aws_codebuild_project" "lms_ecs_build_user" {
  name         = "user-build" #Need to this change this according to service
  description  = "Image Build stage and Terraform planning stage"
  service_role = aws_iam_role.codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type      = "CODEPIPELINE" #GITHUB_ENTERPRSES | BITBUCKET | S3 | CODECOMMIT | CODEPIPELINE | GITHUB | NO_SOURCE
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

resource "aws_codebuild_project" "lms_ecs_apply_user" {
  name         = "user-deploy" #Need to this change this according to service
  description  = "Terraform applying stage"
  service_role = aws_iam_role.codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type      = "CODEPIPELINE" #GITHUB_ENTERPRSES | BITBUCKET | S3 | CODECOMMIT | CODEPIPELINE | GITHUB | NO_SOURCE
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
