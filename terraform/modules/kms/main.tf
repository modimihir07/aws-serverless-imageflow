resource "aws_kms_key" "this" {
  description             = "Customer-managed key for Serverless ImageFlow ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
}

data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = ["kms:*"]
    # In AWS KMS Key Policies, the resource MUST be "*" per AWS KMS design specification.
    # The key policy applies only to the key in which it is defined; scoping to specific ARNs is invalid in KMS.
    resources = ["*"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias_prefix}-${var.environment}"
  target_key_id = aws_kms_key.this.key_id
}
