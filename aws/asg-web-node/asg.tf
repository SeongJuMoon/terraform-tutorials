provider "aws" {
    region = "ap-northeast-2"
}

data "aws_availability_zones" "all" {}

variable "WEB_PORT" {
    description = "web expose service port"
    default = 8080
}

resource "aws_launch_configuration" "asg" {
    image_id = "ami-0f4362c71ffaf7759"
    instance_type = "t2.micro"  
    security_groups = ["${aws_security_group.asg.id}"]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, world" > index.html
                nohup busybox httpd -f -p ${var.WEB_PORT} &
                EOF
}

resource "aws_security_group" "asg" {
    name = "asg_provision_group"

    ingress {
        from_port = "${var.WEB_PORT}"
        to_port = "${var.WEB_PORT}"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_autoscaling_group" "asg" {
    launch_configuration  = "${aws_launch_configuration.asg.id}"
    availability_zones = data.aws_availability_zones.all.names

    load_balancers = ["${aws_elb.asg.name}"]
    health_check_type = "ELB"

    min_size = 2
    max_size = 10

    tag {
        key = "asg_test"
        value = "terrform-asg"
        propagate_at_launch = true
    }
}

resource "aws_elb" "asg" {
    name = "asg-elb"
    availability_zones = data.aws_availability_zones.all.names
    security_groups = ["${aws_security_group.elb.id}"]

    listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = "${var.WEB_PORT}"
        instance_protocol = "http"
    }

    health_check {
        healthy_threshold = 2 
        unhealthy_threshold = 2
        timeout = 3
        interval = 30
        target = "HTTP:${var.WEB_PORT}/"
    }
}

resource "aws_security_group" "elb" {
    name = "sg_elb_test"

    ingress {
        from_port = 70
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

output "elb_dns_name" {
    value = "${aws_elb.asg.dns_name}"
}