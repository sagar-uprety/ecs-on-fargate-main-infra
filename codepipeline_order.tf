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
        ConnectionArn    = "arn:aws:codestar-connections:us-east-1:426857564226:connection/a96d0fa6-04d0-4bac-ab64-988b299a805b" #aws_codestarconnections_connection.ecs-lms-connection.arn
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



resource "aws_iam_role" "codebuild-role" {
  name = "lms-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}


resource "aws_iam_role_policy" "codebuild-policy" {
  name = "lms-codebuild-policy"
  role = aws_iam_role.codebuild-role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:*",
          "s3:*",
          "logs:*",
          "ec2:*",
          "iam:*",
          "vpc:*",
          "servicediscovery:*",
          "application-autoscaling:*",
          "ecs:*",
        "elasticloadbalancing:*"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "TrustPolicyStatementThatAllowsEC2ServiceToAssumeTheAttachedRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codepipeline.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*"
        ],
        "Resource" : [
          "arn:aws:s3:::lms-playground",
          "arn:aws:s3:::lms-playground/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:*"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "cloudformation:DescribeStacks",
          "kms:GenerateDataKey",
          "iam:GetRole",
          "iam:PassRole"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "codestar-connections:GetHost",
          "codestar-connections:ListTagsForResource",
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection",
          "codestar-connections:PassConnection",
          "codestar-connections:UpdateHost",
          "codestar-connections:UpdateConnectionInstallation"
        ],
        "Resource" : [
          "arn:aws:codestar-connections:*:426857564226:host/*",
          "arn:aws:codestar-connections:*:426857564226:connection/*"
        ]
      },
      {
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : [
          "codestar-connections:GetIndividualAccessToken",
          "codestar-connections:CreateConnection",
          "codestar-connections:ListInstallationTargets",
          "codestar-connections:StartOAuthHandshake",
          "codestar-connections:GetInstallationUrl",
          "codestar-connections:ListHosts",
          "codestar-connections:StartAppRegistrationHandshake",
          "codestar-connections:RegisterAppCode",
          "codestar-connections:ListConnections",
          "codestar-connections:CreateHost"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "ECSpermissions",
        "Effect" : "Allow",
        "Action" : [
          "ecs:*"
        ],
        "Resource" : [
          "arn:aws:ecs:*:426857564226:cluster/lms-ecs",
          "arn:aws:ecs:*:426857564226:cluster/lms-ecs/*"
        ]
      },
      {
        "Action" : [
          "codedeploy:*",
          "ecr:*",
          "*"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },

    ]
  })
}
