# bastion host 용 보안 그룹 생성하기
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-ssh-only"
  description = "SSH only"
  vpc_id      = aws_vpc.new_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# 베스천 호스트 생성
resource "aws_instance" "bastion" {
  ami                         = "ami-09cd9fdbf26acc6b4"
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public.id
  key_name                    = aws_key_pair.test1.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "bastion-host"
    Role = "bastion"
  }
}

# 베스천 호스트 공인 주소 
output "베스천호스트_공인주소" {
  value = aws_instance.bastion.public_ip
}