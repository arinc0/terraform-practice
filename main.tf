provider "aws" {
  region = "ap-northeast-1"
}

// ローカル変数は実行時に上書きできない
// 実行時に上書きしたい場合は変数を定義する => variables
locals {
  example_instance_type ="t3.micro"
}

#
module "web_server" {
  // source に main.tf が存在するディレクトリを指定
  source = "./http_server"
  # 変数を渡す
  instance_type = local.example_instance_type
}

# ポリシードキュメントの作成(JSONの代わり)
data "aws_iam_policy_document" "allow_describe_regions" {
  statement {
    effect = "Allow"
    # リージョン一覧を取得する
    actions = ["ec2:DescribeRegions"]
    resources = ["*"]
  }
}

# IAMロール
module "describe_regions_for_ec2" {
  source = "./iam_role"
  # 以下変数
  name = "describe_regions_for_ec2"
  identifier = "ec2.amazonaws.com"
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}

# -- 以下出力 ---------------------------
output "public_dns" {
  # module で定義されたoutputを受け取る
  value = module.web_server.public_dns
}

output "iam_role_arn" {
  value = module.describe_regions_for_ec2.iam_role_arn
}

output "iam_role_name" {
  value = module.describe_regions_for_ec2.iam_role_name
}

