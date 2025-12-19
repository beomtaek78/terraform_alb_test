# 테스트용 서버를 위한 보안 그룹
resource "aws_security_group" "private_instance_sg" {
  vpc_id = aws_vpc.new_vpc.id

  # 웹 서비스 포트
  ingress {
    from_port = var.server_port  
    to_port = var.server_port
    protocol = "tcp"
    cidr_blocks = ["172.18.1.0/24"]  # public subnet 으로부터의 웹 접속만 허용
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["172.18.1.0/24"]  # public subnet으로 부터의 접근만 허용
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # 모든 구간으로의 유출 트래픽 허용
  }
}


# 키페어 등록하기 
resource "aws_key_pair" "test1" {
  key_name = "test1"
  public_key = file("/root/terraformlab/lab7_aws/test1.pem.pub")
}

# private 에 생성될 인스턴스를 위한 "시작 템플릿" 작성
resource "aws_launch_template" "private" {
  name = "asg-launch-template"          # 템플릿 이름
  image_id = "ami-09cd9fdbf26acc6b4"    # 인스턴스 생성에 사용할 이미지(amazon linux)
  key_name = aws_key_pair.test1.key_name
  instance_type = "t3.small"
  network_interfaces {
    associate_public_ip_address = false   # 공인주소할당없음 | nat gateway 를 통해 외부 통신가능
    subnet_id = aws_subnet.private.id
    security_groups = [ aws_security_group.private_instance_sg.id ]
  }
  # 인스턴스 처음 시작할 때 실행할 내용(웹 서버설치, 구성)
  user_data = base64encode(<<-EOF
      #!/bin/bash
      sudo yum -y install httpd
      sudo sed -i "/^Listen/c\Listen ${var.server_port}" /etc/httpd/conf/httpd.conf 
      echo "HELLO AWS" | sudo tee /var/www/html/index.html 
      sudo systemctl restart httpd 
      EOF
      )
  lifecycle {
    create_before_destroy = true  # 먼저 생성한 뒤, 기존 서버 삭제
  }
}


# "시작 템플릿" 이 적용된 "Auto Scale Group"
resource "aws_autoscaling_group" "asg_private" {
  min_size = 1
  max_size = 3
  desired_capacity = 2
  vpc_zone_identifier = [ aws_subnet.private.id ] # ap-northeast-1a

  launch_template {
    id = aws_launch_template.private.id
    version = "$Latest"
  }

  # 라이프사이클 관리 (user_data 가 변경되면 신규 생성/먼저 만들고 기존 인스턴스 삭제)
  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [ aws_launch_template.private.user_data ]
  }

  tag {
    key = "Name"
    value = "asg-private-instance"
    propagate_at_launch = true
  }
}


# output 1 > 태그 Name: asg-private-instance 인 인스턴스의 사설 주소 출력하기
data "aws_instances" "asg-private-instance" {
  filter {
    name = "tag:Name"
    values = [ "asg-private-instance" ]
  }
}

output "사설_구간의_인스턴스_주소" {
  value = data.aws_instances.asg-private-instance.private_ips
}
