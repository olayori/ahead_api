#creating kms key
resource "aws_kms_key" "kms_key" {
  description             = "kms key for ecs cluster"
  deletion_window_in_days = 7
}

#creating cloud watch log groups
resource "aws_cloudwatch_log_group" "ecs_log" {
  name = "ahead-ecs-logs"
}

resource "aws_cloudwatch_log_group" "api-loggroup" {
  name              = "ahead-api-log-group"
  retention_in_days = 3
}

#creating ecs cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name               = "Ahead-ECS-Cluster"
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.kms_key.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_log.name
      }
    }
  }
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

#creating ecs api service
resource "aws_ecs_service" "ahead-api" {
  name                               = "ahead-api"
  cluster                            = aws_ecs_cluster.ecs_cluster.id
  desired_count                      = 2
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_ecs_managed_tags            = false
  scheduling_strategy                = "REPLICA"
  force_new_deployment               = true
  enable_execute_command             = true
  task_definition                    = aws_ecs_task_definition.ahead-api.arn
  service_registries {
    registry_arn   = aws_service_discovery_service.api-service.arn
    container_name = "ahead_api_container"
  }
  deployment_controller {
    type = "ECS"
  }
  network_configuration {
    security_groups  = [aws_security_group.priv-sg.id]
    subnets          = [aws_subnet.subnet-priv.id, aws_subnet.subnet2-priv.id]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE"
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_alb-tg.arn
    container_name   = "ahead_api_container"
    container_port   = 80
  }
}

#creating api task definition 
resource "aws_ecs_task_definition" "ahead-api" {
  family                   = "ahead-api"
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  container_definitions    = <<TASK_DEFINITION
[
    {
        "cpu": 512,
        "essential": true,
        "image": "olayori/ahead_api:latest",
        "memory": 1024,
        "name": "ahead_api_container",
        "portMappings": [
            {
                "containerPort": 80,
                "hostPort": 80
            }
        ],
        "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "${aws_cloudwatch_log_group.api-loggroup.name}",
          "awslogs-region" : "us-east-1",
          "awslogs-stream-prefix" : "main"
        }
      }
    }
]
TASK_DEFINITION
}
