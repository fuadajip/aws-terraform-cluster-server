terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region  = "ap-southeast-1"
  profile = "iot-devops-compute"
}

data "aws_availability_zones" "az-available-all" {}

# create auto scalling group configuration for the instane
resource "aws_autoscaling_group" "iot-ec2-asg" {
  launch_configuration = aws_launch_configuration.iot-ec2-test-lg.id
  availability_zones   = data.aws_availability_zones.az-available-all.names

  # mapping each registered instance in asg to elb
  load_balancers    = [aws_elb.iot-elb-test.name]
  health_check_type = "ELB"

  min_size = 2
  max_size = 3
  tag {
    key                 = "Name"
    value               = "iot-ec2-test-asg"
    propagate_at_launch = true
  }
}


# create ec2 instance
resource "aws_launch_configuration" "iot-ec2-test-lg" {
  image_id        = "ami-08569b978cc4dfa10"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.iot-ec2-test-sg.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }

}


# create security group for the web server
resource "aws_security_group" "iot-ec2-test-sg" {
  name = "iot-ec2-test-sg"

  # Inbound HTTP from anywhere
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}





# ---------------------


# create http alb
resource "aws_elb" "iot-elb-test" {
  name               = "iot-elb-test"
  availability_zones = data.aws_availability_zones.az-available-all.names
  security_groups    = [aws_security_group.iot-elb-test-sg.id]

  # create healthcheck for web server instance
  health_check {
    target              = "http:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }


  # routes listener for incoming http request
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

# create security group for alb
resource "aws_security_group" "iot-elb-test-sg" {
  name = "iot-elb-test-sg"

  // allow outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // allow inbound
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



