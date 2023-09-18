resource "aws_codepipeline" "lms_ecs_pipeline_order" {
  name     = "order_pipeline"
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
      input_artifacts = ["source_output", "build_output"]

      configuration = {
        ProjectName   = aws_codebuild_project.lms_ecs_apply_order.name
        PrimarySource = "source_output"
      }
    }
  }
}

# resource "aws_codestarconnections_connection" "ecs-lms-connection" {
#   name          = "ecs-lms-connection"
#   provider_type = "GitHub"
# }

resource "aws_codebuild_project" "lms_ecs_build_order" {
  name         = "order-build" #Need to this change this according to service
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

resource "aws_codebuild_project" "lms_ecs_apply_order" {
  name         = "order-deploy" #Need to this change this according to service
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
      # {
      #   Action   = ["codecommit:GitPull"]   # need to change this according to service
      #   Effect   = "Allow"
      #   Resource = "*"
      # },
      {
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
        "ecr:UploadLayerPart"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
        "s3:*"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        "Action" : [
          "ec2:DescribeAvailabilityZones",
          "logs:TagResource",
          "iam:CreateRole",
          "iam:CreatePolicy",
          "ec2:CreateSecurityGroup",
          "vpc:CreateSecurityGroup",
          "logs:PutRetentionPolicy",
          "iam:TagRole",
          "iam:TagPolicy",
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup",
          "iam:*"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:CreateService",
          "ecs:*",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:*",
          "elasticloadbalancing:DescribeTargetGroups",
          "iam:CreateServiceLinkedRole",
          "iam:PassRole",
          "servicediscovery:CreateService",
          "servicediscovery:DeleteService",
          "servicediscovery:GetService",
          "servicediscovery:GetInstance",
          "servicediscovery:RegisterInstance",
          "servicediscovery:DeregisterInstance",
          "application-autoscaling:*" #arn:aws:application-autoscaling:us-east-2:426857564226:scalable-target/*
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject"
        ],
        "Resource" : "arn:aws:s3:::lms-playground/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:*"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# resource "aws_iam_policy_attachment" "codebuild-policy-attachment" {
#   name       = "lms-codebuild-policy-attachment"
#   roles      = ["${aws_iam_role.codebuild-role.name}"]
#   policy_arn = aws_iam_role_policy.codebuild-policy.
# }

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
