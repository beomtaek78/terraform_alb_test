############################
# Load Balancer용 보안그룹
############################
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.new_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "alb-sg"
  }
}

############################
# Application Load Balancer(aws_elb[class] >> aws_lb[application|network])
############################
resource "aws_lb" "public_alb" {
  name               = "public-alb"
  internal           = false                 # internet facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [aws_subnet.public.id, aws_subnet.public10.id] # 각각 1a, 1c 에 따로 속한다.

  tags = {
    Name = "public-alb"
  }
}

############################
# Target Group (private ASG 대상)
############################
resource "aws_lb_target_group" "asg_tg" {
  name     = "asg-target-group"
  port     = var.server_port    # 인스턴스들의 8001 과 같은 포트로 넘기겠다
  protocol = "HTTP"
  vpc_id   = aws_vpc.new_vpc.id

  health_check {
    path                = "/index.html"    # /var/www/html/index.html
    port                = "traffic-port"   # port = var.server_port 로 전송
    interval            = 30               # 30초 마다 접속테스트    
    timeout             = 5                # 5ms 이내에 응답이 돌아와야 한다.
    healthy_threshold   = 2                # 접속테스트가 연속 2번 성공해야 정상 등록 
    unhealthy_threshold = 2                # 연속 두번 실패하면 backend 에서 제거 
    matcher             = "200"            # index.html 로 접속하면 http 접속 코드 '200 OK' 면 성공 
  }

  tags = {
    Name = "asg-tg"
  }
}

############################
# Listener (80 → Target Group)
############################
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public_alb.arn  # id 는 이해하기 어렵다! 이름으로 구분해 주기 위해 arn 
  port              = 80
  protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.asg_tg.arn
#   }

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

}

############################
# ASG 와 Target Group 연결
############################
resource "aws_autoscaling_attachment" "asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.asg_private.name
  lb_target_group_arn    = aws_lb_target_group.asg_tg.arn
}

############################
# ALB DNS 출력
############################
output "alb_dns_이름" {
  value = aws_lb.public_alb.dns_name
}
