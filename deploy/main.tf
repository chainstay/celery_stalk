locals {
  app_prefix             = "${var.application}"
  codebuild_project_name = "${var.application}-build-image"
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
  name               = "${var.application}-codepipeline"
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

resource "aws_iam_role_policy_attachment" "codepipeline" {
  policy_arn = "${aws_iam_policy.codepipeline.arn}"
  role       = "${aws_iam_role.codepipeline.id}"
}

resource "aws_codepipeline" "source_build" {
  # TODO: Name pipeline by the branch it builds
  name     = "${var.application}-master-pipeline"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store = {
    location = "${aws_s3_bucket.codepipeline_state.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["celery_stalk"]

      # TODO: Interpolate these variables
      configuration = {
        OAuthToken = "${var.github_oauth_token}"
        Owner      = "chainstay"
        Repo       = "celery_stalk"
        Branch     = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["celery_stalk"]
      output_artifacts = ["dockerrun-web", "dockerrun-worker"]

      configuration = {
        ProjectName = "${local.codebuild_project_name}"
      }
    }
  }
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
      "s3:*",
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
  name         = "${local.codebuild_project_name}"
  service_role = "${aws_iam_role.codebuild.arn}"

  artifacts {
    # this build does generate artifacts, however they must be identifiable by
    # name in order to send them to distinct codepipeline stages. See secondary_artifacts
    type = "CODEPIPELINE"
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
    type = "CODEPIPELINE"
  }

  # secondary_artifacts = [
  #   {
  #     artifact_identifier = "dockerrun-web"
  #     encryption_disabled = true
  #     type                = "CODEPIPELINE"
  #   },
  #   {
  #     artifact_identifier = "dockerrun-worker"
  #     encryption_disabled = true
  #     type                = "CODEPIPELINE"
  #   },
  # ]
}
