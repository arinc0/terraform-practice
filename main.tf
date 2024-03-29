// AWSやGCPなどの差分を吸収する
// terraform get か terraform initが必要
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
  # iam role, iam policy用の名前
  name = "describe_regions_for_ec2"
  # iam roleを関連づけるAWSサービスの識別子
  identifier = "ec2.amazonaws.com"
  # ポリシードキュメント
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}

# -- S3プライベートバケット -----------------------------------------
resource "aws_s3_bucket" "private" {
  bucket = "terraform-private-750c2929106219961e7339100749e6cc3015230f"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket = aws_s3_bucket.private.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# -- S3パブリックバケット  ---------------------------------

resource "aws_s3_bucket" "public" {
  bucket = "terraform-public-750c2929106219961e7339100749e6cc3015230f"
  acl = "public-read"

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["https://example.com"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket" "alb_log" {
  bucket = "terraform-alb-log-750c2929106219961e7339100749e6cc3015230f"

  # バケットが空でなくてもdestroyで削除される
  force_destroy = true

  lifecycle_rule {
    enabled = true

    expiration {
      days = "180"
    }
  }
}

data "aws_iam_policy_document" "alb_log" {
  statement {
    effect = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      # rootと配下をそれぞれ指定
      aws_s3_bucket.alb_log.arn,
      "${aws_s3_bucket.alb_log.arn}/*"
    ]

    principals {
      # ELBのアカウントID リージョンごと違う
      identifiers = ["582318560864"]
      type        = "AWS"
    }
  }
}

// ポリシードキュメント(JSON)をバケットに設定
resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

// :::::::::::::::::::::::::::::::::::::::::::::
//  パブリックサブネット
// :::::::::::::::::::::::::::::::::::::::::::::

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  // AWSのDNSサーバーによる名前解決を有効にする
  enable_dns_support = true
  // パブリックDNSホスト名を自動的に割り当てる
  enable_dns_hostnames = true

  tags = {
    Name = "example"
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.example.id
  // VPCは/16、サブネットは/24単位にするとわかりやすい
  cidr_block = "10.0.0.0/24"
  // サブネットで起動したインスタンスにパブリックIPを自動的に割り当ててくれる
  // パブリックIPアドレスを自動的に割り当ててくれる
  map_public_ip_on_launch = true
  availability_zone = "ap-northeast-1a"
}

// VPCは単体ではインターネットと接続できないので
// IGWを作成してVPC<=>インターネット間の間で通信ができるようにします
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

// IGWだけではインターネットと通信できない
// ネットワークにデータを流す為。ルーティング情報を管理するルートテーブルが必要
// ルートテーブルはVPC内の通信を有効にするためローカルルートが自動的に作成される
// これによってVPC内はルーティングされる
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id
}

// ルートはルートテーブルの１レコードに該当
resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id
  gateway_id = aws_internet_gateway.example.id
  // 全ての通信 ≒ デフォルトルート
  // をインターネットゲートウェイに送る
  destination_cidr_block = "0.0.0.0/0"
}

// ルートテーブルをサブネットに関連づける
// VPCに紐付けても、このVPCでこのルートテーブルを使用する
// という設定のみなので、サブネットごとに設定をする
// 関連づけを忘れた場合デフォルトルートテーブルが
// 自動的に使用されるがアンチパターンなので関連づけること
resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
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

output "alb_log_policy_json" {
  value = data.aws_iam_policy_document.alb_log.json
}
