locals {
  app_prefix = "${var.application}"
}

terraform {
  backend "s3" {
    bucket  = "chainstay-terraform-state"
    key     = "celery_stalk"
    region  = "us-east-1"
    profile = "chainstay-terraform"
  }
}

provider "aws" {
  profile = "chainstay-terraform"
  region  = "us-east-1"
}

#
# Codepipeline
#

resource "aws_s3_bucket" "codepipeline_state" {
  bucket = "${local.app_prefix}-codepipeline-state"
}

data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "celery-stalk-codepipeline"
  assume_role_policy = "${data.aws_iam_policy_document.codepipeline_assume_role.json}"
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    actions = [
      "autoscaling:*",
      "cloudformation:*",
      "cloudwatch:*",
      "codebuild:*",
      "ec2:*",
      "ecs:*",
      "elasticbeanstalk:*",
      "elasticloadbalancing:*",
      "iam:PassRole",
      "logs:PutRetentionPolicy",
      "rds:*",
      "sns:*",
      "s3:*",
      "sqs:*",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "codepipeline" {
  name   = "${var.application}-codepipeline-policy"
  path   = "/service-role/"
  policy = "${data.aws_iam_policy_document.codepipeline.json}"
}

#
# Codebuild
#

data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.application}-codebuild"
  assume_role_policy = "${data.aws_iam_policy_document.codebuild_assume_role.json}"
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecs:RunTask",
      "iam:PassRole",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ssm:GetParameters",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "codebuild" {
  name   = "${var.application}-codebuild"
  path   = "/service-role/"
  policy = "${data.aws_iam_policy_document.codebuild.json}"
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  policy_arn = "${aws_iam_policy.codebuild.arn}"
  role       = "${aws_iam_role.codebuild.id}"
}

resource "aws_codebuild_project" "build_image" {
  name         = "${var.application}-build-image"
  service_role = "${aws_iam_role.codebuild.arn}"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/docker:18.09.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true                           # required for docker codebuild image

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "us-east-1"
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = "248213449538"
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = "celery_stalk"
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
  }

  source {
    type                = "GITHUB"
    location            = "${var.codebuild_github_source}"
    report_build_status = true
  }
}
