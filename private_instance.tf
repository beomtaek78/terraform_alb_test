# 테스트용 서버를 위한 보안 그룹
resource "aws_security_group" "private_instance_sg" {
  vpc_id = aws_vpc.new_vpc.id

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
    associate_public_ip_address = false
    subnet_id = aws_subnet.private.id
    security_groups = [ aws_security_group.private_instance_sg.id ]
  }
}


# "시작 템플릿" 이 적용된 "Auto Scale Group"
resource "aws_autoscaling_group" "asg_private" {
  min_size = 1
  max_size = 3
  desired_capacity = 3
  vpc_zone_identifier = [ aws_subnet.private.id ] # ap-northeast-1a

  launch_template {
    id = aws_launch_template.private.id
    version = "$Latest"
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
