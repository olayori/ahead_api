#Creating service discovery namespace
resource "aws_service_discovery_private_dns_namespace" "dns" {
  name        = "ahead.int"
  description = "Namespace for web service"
  vpc         = aws_vpc.vpc.id
}

#adding api to service discovery
resource "aws_service_discovery_service" "api-service" {
  name = "api"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.dns.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

#adding database to service discovery
resource "aws_service_discovery_service" "database" {
  name = "database"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.dns.id
    dns_records {
      ttl  = 60
      type = "CNAME"
    }
    routing_policy = "WEIGHTED"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

#registering database instance to database service
resource "aws_service_discovery_instance" "database_instance" {
  instance_id = "database-instance"
  service_id  = aws_service_discovery_service.database.id

  attributes = {
    AWS_INSTANCE_CNAME = aws_rds_cluster.dbserver.endpoint
  }
}


# Creating api application load balancer
resource "aws_lb" "api_alb" {
  name               = "api-public-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb-sg.id]
  subnets            = [aws_subnet.subnet1-pub.id, aws_subnet.subnet2-pub.id]
  tags = {
    Name = "api-public-lb"
  }
}

#Creating api target group
resource "aws_lb_target_group" "api_alb-tg" {
  name        = "api-alb-target-group"
  port        = 80
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id
  protocol    = "HTTP"
  health_check {
    enabled  = true
    interval = 10
    path     = "/"
    port     = 80
    protocol = "HTTP"
    matcher  = "200-499"
  }
  tags = {
    Name = "api-alb-target-group"
  }
}

#Creating api load balancer listener
resource "aws_lb_listener" "api_alb-ls" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_alb-tg.arn
  }
}

#Creating cloudfront distribution for api
resource "aws_cloudfront_distribution" "api_distribution" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_All"
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    target_origin_id       = aws_lb.api_alb.dns_name
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name = aws_lb.api_alb.dns_name
    origin_id   = aws_lb.api_alb.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1"
  }
}

#DNS Configuration

resource "aws_route53_zone" "ahead" {
  name = "ahead.com"
}

resource "aws_route53_record" "api-dns-record" {
  zone_id = aws_route53_zone.ahead.zone_id
  name    = "api.${aws_route53_zone.ahead.name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.api_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.api_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}