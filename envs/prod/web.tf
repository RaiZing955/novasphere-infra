# --- Security Groups (module de l'equipe, appele deux fois) --------------------
# ALB : seule porte publique, port 80 uniquement (le module refuse 0.0.0.0/0 sur tout autre port).
module "sg_alb" {
  source = "git::https://github.com/RaiZing955/terraform-aws-web-sg.git?ref=v1.0.0"

  name          = "${local.name}-alb"
  vpc_id        = module.vpc.vpc_id
  ingress_port  = 80
  allowed_cidrs = ["0.0.0.0/0"]
  egress_ports  = [80]
}

# Instances : port 80 depuis le Security Group de l'ALB uniquement, aucun SSH nulle part.
module "sg_web" {
  source = "git::https://github.com/RaiZing955/terraform-aws-web-sg.git?ref=v1.0.0"

  name                     = "${local.name}-web"
  vpc_id                   = module.vpc.vpc_id
  ingress_port             = 80
  source_security_group_id = module.sg_alb.security_group_id
  egress_ports             = [80, 443]
}

# --- Launch Template ----------------------------------------------------------
resource "aws_launch_template" "web" {
  name_prefix   = "${local.name}-web-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.sg_web.security_group_id]

  iam_instance_profile {
    name = local.instance_profile_name
  }

  # IMDSv2 exige : plus de reponse aux requetes metadata sans jeton de session.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Amorcage court : seul le NOM du parametre est passe, jamais sa valeur.
  user_data = base64encode(templatefile("${path.module}/bootstrap.sh", {
    environment = var.environment
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-web" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- ALB, target group, listener ----------------------------------------------
resource "aws_lb" "web" {
  #checkov:skip=CKV_AWS_150:pas de protection contre la suppression : tout est detruit en fin de session de lab
  #checkov:skip=CKV_AWS_91:logs d'acces ALB non actives (bucket S3 + politique dediee hors perimetre du lab)
  #checkov:skip=CKV2_AWS_28:pas de WAF : cout et hors perimetre du cahier des charges
  name               = local.name
  load_balancer_type = "application"
  internal           = false
  subnets            = module.vpc.public_subnets
  security_groups    = [module.sg_alb.security_group_id]

  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "web" {
  name                 = "${local.name}-web"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:HTTPS = extension non retenue, pas de domaine ni de certificat dans le lab
  #checkov:skip=CKV_AWS_103:idem, listener HTTP uniquement
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Reponse fixe servie par l'ALB lui-meme : demonstration rapide et visible
# (changer release_label dans une PR => plan => merge => curl /release).
resource "aws_lb_listener_rule" "release" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "novasphere ${var.environment} - release ${var.release_label}\n"
      status_code  = "200"
    }
  }

  condition {
    path_pattern {
      values = ["/release"]
    }
  }
}

# --- Auto Scaling Group --------------------------------------------------------
resource "aws_autoscaling_group" "web" {
  name                = "${local.name}-web"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = module.vpc.public_subnets
  target_group_arns   = [aws_lb_target_group.web.arn]

  # ELB : une instance qui ne repond plus sur / est remplacee.
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-web"
    propagate_at_launch = true
  }
}
