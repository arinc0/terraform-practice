/*
# ポリシードキュメントの作成(JSONの代わり)
data "aws_iam_policy_document" "allow_describe_regions" {
  statement {
    effect = "Allow"
    # リージョン一覧を取得する
    actions = ["ec2:DescribeRegions"]
    resources = ["*"]
  }
}

# 権限を定義
# IAMポリシードキュメントをIAMポリシーに設定する
resource "aws_iam_policy" "example" {
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}

# 信頼ポリシー作成(JSONの代わり)
# EC2が引き受けるロール
# IAMロールで自信を何のサービスに関連づける為に使用する
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    # EC2にのみ関連づけることができる設定
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

# IAMロールにassume role をJSONで定義
resource "aws_iam_role" "example" {
  name = "example"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "example" {
  policy_arn = aws_iam_policy.example.arn
  role       = aws_iam_role.example.name
}
*/
