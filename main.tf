# 새로운 VPC 생성하기
resource "aws_vpc" "new_vpc" {
  cidr_block = "172.18.0.0/16"

  tags = {
    Name = "new_vpc"
  }
}

# 서브넷 > 퍼블릭 서브넷(공인주소 할당 가능)
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.new_vpc.id
  cidr_block = "172.18.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-northeast-1a"
}

# 서브넷 > 프라이빗 서브넷(공인주소 할당 불가능)
resource "aws_subnet" "private" {
  vpc_id = aws_vpc.new_vpc.id
  cidr_block = "172.18.2.0/24"
  map_public_ip_on_launch = false
  availability_zone = "ap-northeast-1a"
}

# 인터넷 게이트웨이 > vpc 에 속하도록 해야 함
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.new_vpc.id
  tags = {
    Name = "new_igw"
  }
}

# EIP 발급받기 > NAT Gateway 에서 사용할 용도
resource "aws_eip" "nat" {
  domain = "vpc"
}

# NAT GATEWAY 생성
resource "aws_nat_gateway" "my_natgw" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public.id
  depends_on = [ aws_internet_gateway.gw ]
}

# Public subnet 을 위한 라우팅 테이블 작성(local[자동생성], 0.0.0.0/0-igw)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.new_vpc.id
}

resource "aws_route" "public_internet_access" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id 
}

# Private subnet 을 위한 라우팅 테이블 작성(local[자동생성], 0.0.0.0/0-ng)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.new_vpc.id
}

resource "aws_route" "private_nat_access" {
  route_table_id = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.my_natgw.id
}

# 작성된 라우팅 테이블을 서브넷과 연결해야 한다
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}