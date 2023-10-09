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
          "ssm:*",
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
          "arn:aws:codestar-connections:*:*:host/*",
          "arn:aws:codestar-connections:*:*:connection/*"
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
          "arn:aws:ecs:*:*:cluster/lms-ecs",
          "arn:aws:ecs:*:*:cluster/lms-ecs/*"
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
