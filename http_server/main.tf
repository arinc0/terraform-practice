# default を設定しておく
variable "instance_type" {
  default = "t3.nano"
  type = string
}

# SG
# SGの80番ポートにリクエストがあったら、EC2の80番にフォワードする
resource "aws_security_group" "for_default_ec2" {
  # セキュリティグループ名
  name = "for_default_ec2"

  ingress {
    from_port = 80
    protocol  = "tcp"
    to_port   = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Name (一番左に表示される名前)
  tags = {
    Name = "for_default_ec2"
  }
}

# データソースを使うと外部データを参照できる
# データソースを参照、awsのamiイメージ、recent_amazon_linux_2という名前をつける
data "aws_ami" "recent_amazon_linux_2" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# EC2インスタンスにapacheをインストールする
resource "aws_instance" "default" {
  ami = data.aws_ami.recent_amazon_linux_2.image_id
  vpc_security_group_ids = [aws_security_group.for_default_ec2.id]
  instance_type = var.instance_type

  user_data = file("./http_server/user_data.sh")

  tags = {
    Name = "default"
  }
}

output "public_dns" {
  value = aws_instance.default.public_dns
}