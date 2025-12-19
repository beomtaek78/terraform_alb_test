# 사설구간의 웹서버를 위한 웹 서비스 포트
variable "server_port" {
  description = "웹 서버의 웹 포트"
  type = number
  default = 8001
}