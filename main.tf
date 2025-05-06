######################################
# VPC
######################################
resource "aws_vpc" "Bayoucityclinic_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "Bayoucityclinic_vpc"
    Owner = "Chris"
    Environment = "Dev"
    Project = "Bayoucityclinic"
  }
  
}

######################################
# Internet Gateway
######################################
resource "aws_internet_gateway" "Bayoucityclinic_igw" {
  vpc_id = aws_vpc.Bayoucityclinic_vpc.id

  tags = {
    Name = "dBayoucityclinic_igw"
    Owner = "Chris"
    Environment = "Dev"
    Project = "Bayoucityclinic"
  }
  
}

######################################
# Nat Gateway / Ec2 Instance
######################################
resource "aws_instance" "bayoucitclinic_nat_instance" {
  ami = "ami-058a8a5ab36292159"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.Bayoucityclinic_public_subnet.id
  associate_public_ip_address = true
  source_dest_check = false

  tags = {
    Name = "Bayoucityclinic_nat_instance"
    Owner = "Chris"
    Environment = "Dev"
    Project = "Bayoucityclinic"
  }


}
######################################
# Public Subnets
######################################
resource "aws_subnet" "Bayoucityclinic_public_subnet" {
  vpc_id            = aws_vpc.Bayoucityclinic_vpc.id
  cidr_block        = "10.0.10.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
  
}
######################################
# Private Subnet
######################################
resource "aws_subnet" "Bayoucityclinic_private_subnet" {
  vpc_id            = aws_vpc.Bayoucityclinic_vpc.id
  cidr_block        = "10.0.20.0/24"
  
}
######################################
# Public RT
######################################
resource "aws_route_table" "Bayoucityclinic_public_rt" {
  vpc_id = aws_vpc.Bayoucityclinic_vpc.id

  route {
    gateway_id = aws_internet_gateway.Bayoucityclinic_igw.id
    cidr_block = "0.0.0.0/0"
  
}
    tags = {
        Name = "Bayoucityclinic_public_rt"
        Owner = "Chris"
        Environment = "Dev"
        Project = "Bayoucityclinic"
    }
    
    }
######################################
# Private RT
######################################

resource "aws_route_table" "Bayoucityclinic_private_rt" {
  vpc_id = aws_vpc.Bayoucityclinic_vpc.id


  tags = {
    Name = "Bayoucityclinic_private_rt"
    Owner = "Chris"
    Environment = "Dev"
    Project = "Bayoucityclinic"
  }
  
}

resource "aws_route" "ec2_nat_route" {
  route_table_id = aws_route_table.Bayoucityclinic_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  instance_id = aws_instance.bayoucitclinic_nat_instance.id
  
}
######################################
# RT association
######################################
resource "aws_route_table_association" "Bayoucityclinic_public_rt_association" {
  subnet_id      = aws_subnet.Bayoucityclinic_public_subnet.id
  route_table_id = aws_route_table.Bayoucityclinic_public_rt.id

}

resource "aws_route_table_association" "Bayoucityclinic_private_rt_association" {
  subnet_id      = aws_subnet.Bayoucityclinic_private_subnet.id
  route_table_id = aws_route_table.Bayoucityclinic_private_rt.id
  
}

######################################
# ALB Security Group
######################################

resource "aws_security_group" "bayoucityclinic_alb_sg" {
  vpc_id = aws_vpc.Bayoucityclinic_vpc.id
  name   = "bayoucityclinic_alb_sg"
  description = "Allows HTTPS traffic to ALB"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks  = ["0.0.0.0/0"]
  }
}
######################################
# OpenEMR EC2 Security Group
######################################

resource "aws_security_group" "bayoucityclinic_openEMR_sg" {
  vpc_id = aws_vpc.Bayoucityclinic_vpc.id
  name   = "bayoucityclinic_openEMR_sg"
  description = "Allows HTTP and HTTPS traffic to OpenEMR"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.bayoucityclinic_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks  = ["0.0.0.0/0"]
  }
  

}

######################################
# RDS Security Group
######################################


resource "aws_security_group" "bayoucityclinic_rds_sg" {
    vpc_id = aws_vpc.Bayoucityclinic_vpc.id
    name = "bayoucityclinic_rds_sg"
    description = "allows MySQL access to RDS"

    ingress  {
        from_port = 3306
        to_port = 3306
        protocol = tcp
        security_groups = [aws_security_group.bayoucityclinic_openEMR_sg.id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}
######################################
# Application Load Balancer
######################################

resource "aws_lb" "bayoucityclinic_alb" {
  name               = "bayoucityclinic-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.bayoucityclinic_alb_sg.id]
  subnets            = [aws_subnet.Bayoucityclinic_public_subnet.id]

  enable_deletion_protection = false

  enable_http2 = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "bayoucityclinic_alb"
    Owner = "Chris"
    Environment = "Dev"
    Project = "Bayoucityclinic"
  }
  
}

#######################################
# Ec2 Instance
#######################################

resource "aws_instance" "bayoucityclinic_openEMR_instance" {
  ami = "ami-058a8a5ab36292159"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.Bayoucityclinic_private_subnet.id
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.bayoucityclinic_openEMR_sg.id]
  key_name = "bayoucityclinic_keypair"

  user_data = <<-EOF
  #!/bin/bash
    yum update -y

    amazon-linux-extras enable php7.4
    yum install -y httpd php php-mysqlnd unzip wget

    systemctl start httpd
    systemctl enable httpd
    
    cd /var/www/html
    wget https://sourceforge.net/projects/openemr/files/OpenEMR%20Current/7.0.3/openemr-7.0.3.tar.gz
    tar -xzf openemr-7.0.3.tar.gz
    mv openemr-7.0.3 openemr
    rm -rf openemr-7.0.3
    chown -R apache:apache openemr
    chmod -R 755 openemr
    systemctl restart httpd

  EOF


  tags = {
    Name = "bayoucityclinic_openEMR_instance"
    Owner = "Chris"
    Environment = "Dev"
    Project = "Bayoucityclinic"
  }
  
}
#######################################
# Subnet Group for RDS
#######################################
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "bayoucityclinic_rds_subnet_group"
  subnet_ids = [aws_subnet.Bayoucityclinic_private_subnet.id]
  

  tags = {
    Name = "bayoucityclinic_rds_subnet_group"
    Owner = "Chris"
    Environment = "Dev"
    Project = "Bayoucityclinic"
  }
  
}

#######################################
# RDS Instance
#######################################

resource "aws_db_instance" "bayoucityclinici_rds" {
    instance_class = "db.t2.micro"
    allocated_storage = 20
    engine = "mysql"
    identifier = "openemr-db"
    engine_version = "8.0"
    username = "openemradmin"
    password = var.rds_password
    db_name = "openemr"
    port = 3306
    publicly_accessible = false
    skip_final_snapshot = true
    multi_az = false
    backup_retention_period = 7

    vpc_security_group_ids = [aws_security_group.bayoucityclinic_rds_sg.id]
    db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

    tags = {
        Name = "bayoucityclinic_rds"
        Owner = "Chris"
        Environment = "Dev"
        Project = "Bayoucityclinic"
    }

  
}

#######################################
# ALB Target Group w/ attachment
#######################################

resource "aws_lb_target_group" "bayoucityclinic_alb_tg" {
    name = "bayoucityclinic-alb-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.Bayoucityclinic_vpc.id
    target_type = "instance"

    health_check {
        path = "/openemr"
        interval = 30
        timeout = 5
        healthy_threshold = 2
        unhealthy_threshold = 2
        matcher = "200-399"
    }

    tags = {
      name = "bayoucityclinic_alb_tg"
      Owner = "Chris"
      Environment = "Dev"
      Project = "Bayoucityclinic"
    }
}

resource "aws_lb_target_group_attachment" "bayoucityclinic_alb_tg_attachment" {
    target_group_arn = aws_lb_target_group.bayoucityclinic_alb_tg.arn
    target_id = aws_instace.bayoucityclinic_openEMR_instance.id
    port = 80
  }