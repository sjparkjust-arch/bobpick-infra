# 1. 시작 템플릿 (Launch Template)
resource "aws_launch_template" "app_lt" {
  name_prefix   = "bobpick-app-lt-"
  image_id      = "ami-078f32a3cf45126fd"
  instance_type = "t3.micro"
  key_name      = "mysite-key"

  iam_instance_profile {
    name = aws_iam_instance_profile.app_ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    cd /home/ubuntu/menu-recommend
    sudo -u ubuntu git pull origin main
    sudo -u ubuntu venv/bin/pip install -r requirements.txt
    sudo -u ubuntu venv/bin/python manage.py migrate
    sudo -u ubuntu venv/bin/python manage.py collectstatic --noinput
    sudo systemctl restart gunicorn
  EOF
  )


  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "bobpick-app-asg-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 2. 오토스케일링 그룹 (Auto Scaling Group)
resource "aws_autoscaling_group" "app_asg" {
  name_prefix      = "bobpick-app-asg-"
  desired_capacity = 2
  max_size         = 4
  min_size         = 2

  vpc_zone_identifier = [aws_subnet.private_app_a.id, aws_subnet.private_app_c.id]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "bobpick-app-server"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
