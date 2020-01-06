terraform {
  required_version = ">=0.12"
}

provider "aws" {
  region  = "ap-southeast-1"
  profile = "iot-devops-compute"
}

data "aws_availability_zones" "az-available-all" {}

# create ec2 instance
resource "aws_launch_configuration" "iot-ec2-lg" {
  ami             = "ami-08569b978cc4dfa10"
  instance_type   = "t2.micro"
  security_groups = []

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}


# create auto scalling group configuration for the instane
resource "aws_autoscaling_group" "iot-ec2-asg" {
  launch_configuration = aws_launch_configuration.iot-ec2-lg
  availability_zones   = data.aws_availability_zones.az-available-all.names

  min_size = 2
  max_size = 3
  tag {
    key                 = "Name"
    value               = "iot-ec2-test-asg"
    propagate_at_launch = true
  }
}

# create http alb
resource "aws_elb" "iot-elb-test" {
  name               = "iot-elb-test"
  availability_zones = data.aws_availability_zones.az-available-all.names

  # routes listener for incoming http request
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.server_ports
    instance_protocol = "http"
  }
}


