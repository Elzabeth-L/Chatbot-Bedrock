data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  github_oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  repository_subject       = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}"
}

data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.repository_subject}:pull_request",
        "${local.repository_subject}:ref:refs/heads/main",
        "${local.repository_subject}:ref:refs/heads/${var.feature_branch}",
      ]
    }
  }
}

data "aws_iam_policy_document" "github_deploy_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.repository_subject}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "chatbot-bedrock-demo-github-plan"
  description          = "Repository-scoped GitHub Actions OIDC role for Chatbot-Bedrock"
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.github_plan_trust.json
  tags = {
    Project   = "bedrock-rag-demo"
    ManagedBy = "bootstrap"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "chatbot-bedrock-demo-github-deploy"
  description          = "Repository-scoped GitHub Actions OIDC role for Chatbot-Bedrock"
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.github_deploy_trust.json
  tags = {
    Project   = "bedrock-rag-demo"
    ManagedBy = "bootstrap"
  }
  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "github_deploy_supplemental" {
  statement {
    sid       = "ReadStateBucketMetadata"
    actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [var.state_key, "${var.state_key}.tflock"]
    }
  }

  statement {
    sid = "ReadAndWriteApplicationState"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.state.arn}/${var.state_key}",
      "${aws_s3_bucket.state.arn}/${var.state_key}.tflock",
    ]
  }

  statement {
    sid       = "ReleaseApplicationStateLock"
    actions   = ["s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/${var.state_key}.tflock"]
  }

  statement {
    sid = "ManageApplicationBudgetTags"
    actions = [
      "budgets:TagResource",
      "budgets:UntagResource",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:budgets::${data.aws_caller_identity.current.account_id}:budget/bedrock-rag-demo-*",
    ]
  }

  statement {
    sid = "ManageApplicationTableTTL"
    actions = [
      "dynamodb:DescribeTimeToLive",
      "dynamodb:UpdateTimeToLive",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/bedrock-rag-demo-*",
    ]
  }
}

resource "aws_iam_role_policy" "github_deploy_supplemental" {
  name   = "chatbot-bedrock-deploy-supplemental"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy_supplemental.json
}
