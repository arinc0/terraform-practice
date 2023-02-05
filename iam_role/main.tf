variable "name" {}
variable "policy" {}
variable "identifier" {}


# ロールを引き受ける設定定義ドキュメント
# サービスEC2用のassume role policy document
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    # ロールを引き受ける主体
    principals {
      identifiers = [var.identifier]
      type        = "Service"
    }
  }
}

# IAMロールには受け入れるロール定義を設定する
resource "aws_iam_role" "default" {
  name = var.name
  # assumeRoleについて書かれたポリシードキュメントを指定
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# 入力されたポリシードキュメントを元にpolicyを作成
resource "aws_iam_policy" "default" {
  name = var.name
  policy = var.policy
}

# role に policy をアタッチする
resource "aws_iam_role_policy_attachment" "default" {
  policy_arn = aws_iam_policy.default.arn
  role       = aws_iam_role.default.name
}


# -- 以下出力 --------------------------
output "iam_role_arn" {
  value = aws_iam_role.default.arn
}

output "iam_role_name" {
  value = aws_iam_role.default.name
}
