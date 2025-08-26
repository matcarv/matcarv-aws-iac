# IAM Role for EC2 CloudWatch Agent
resource "aws_iam_role" "ec2_cloudwatch" {
  name = "${var.project_name}-ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-ec2-cloudwatch-role"
    Description = "IAM role for EC2 instances to send metrics to CloudWatch"
    Service     = "EC2"
  })
}

# IAM Policy Attachment for CloudWatch Agent
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_cloudwatch" {
  name = "${var.project_name}-ec2-cloudwatch-profile"
  role = aws_iam_role.ec2_cloudwatch.name

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-ec2-cloudwatch-profile"
    Description = "Instance profile for EC2 CloudWatch Agent"
    Service     = "EC2"
  })
}

# Launch Template
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_cloudwatch.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
      kms_key_id  = aws_kms_key.ebs.arn
    }
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2
              
              # Install CloudWatch Agent
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
              dpkg -i -E ./amazon-cloudwatch-agent.deb
              
              # Configure CloudWatch Agent
              cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOL'
              {
                "agent": {
                  "metrics_collection_interval": 300,
                  "run_as_user": "cwagent"
                },
                "metrics": {
                  "namespace": "CWAgent",
                  "metrics_collected": {
                    "cpu": {
                      "measurement": [
                        "cpu_usage_idle",
                        "cpu_usage_iowait",
                        "cpu_usage_user",
                        "cpu_usage_system"
                      ],
                      "metrics_collection_interval": 300,
                      "totalcpu": false
                    },
                    "disk": {
                      "measurement": [
                        "used_percent"
                      ],
                      "metrics_collection_interval": 300,
                      "resources": [
                        "*"
                      ]
                    },
                    "diskio": {
                      "measurement": [
                        "io_time"
                      ],
                      "metrics_collection_interval": 300,
                      "resources": [
                        "*"
                      ]
                    },
                    "mem": {
                      "measurement": [
                        "mem_used_percent"
                      ],
                      "metrics_collection_interval": 300
                    },
                    "netstat": {
                      "measurement": [
                        "tcp_established",
                        "tcp_time_wait"
                      ],
                      "metrics_collection_interval": 300
                    },
                    "swap": {
                      "measurement": [
                        "swap_used_percent"
                      ],
                      "metrics_collection_interval": 300
                    }
                  }
                }
              }
              EOL
              
              # Start CloudWatch Agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
              
              # Configure Apache
              systemctl start apache2
              systemctl enable apache2
              echo "<h1>Hello from ${var.project_name} on Ubuntu!</h1>" > /var/www/html/index.html
              echo "<p>Server: $(hostname)</p>" >> /var/www/html/index.html
              echo "<p>Date: $(date)</p>" >> /var/www/html/index.html
              echo "<p>CloudWatch Agent: Enabled</p>" >> /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name        = "${var.project_name}-instance"
      Description = "Web server instance running Ubuntu with Apache and CloudWatch Agent"
      Service     = "WebServer"
    })
  }

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-launch-template"
    Description = "Launch template for EC2 instances with Ubuntu, Apache and CloudWatch Agent"
  })
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = aws_subnet.private[*].id
  target_group_arns         = [aws_lb_target_group.main.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Description"
    value               = "Auto Scaling Group for web servers with CloudWatch monitoring"
    propagate_at_launch = false
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "production"
    propagate_at_launch = true
  }

  tag {
    key                 = "CreatedDate"
    value               = "2025-08-26"
    propagate_at_launch = false
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}
