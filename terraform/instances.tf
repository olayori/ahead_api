#Getting AMI ID for the latest Amazon Linux 2 from SSM endpoint
data "aws_ssm_parameter" "linuxAmi" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#Creating keypair for instances from keys on my local system
resource "aws_key_pair" "key" {
  key_name   = "main-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

#Creating a jump server
resource "aws_instance" "jump_server" {
  ami                         = data.aws_ssm_parameter.linuxAmi.value
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.dmz-sg.id]
  subnet_id                   = aws_subnet.subnet1-pub.id
  tags = {
    Name = "jump_server"
  }
}


#Creating db subnet group
resource "aws_db_subnet_group" "dbgroup" {
  name       = "db-subnet-grop"
  subnet_ids = [aws_subnet.subnet-priv.id, aws_subnet.subnet2-priv.id]
  tags = {
    Name = "MyDBsubnetgroup"
  }
}

resource "random_password" "password" {
  length           = 16
  special          = true
}

#Creating pgsql aurora cluster on private subnet
resource "aws_rds_cluster" "dbserver" {
  cluster_identifier           = "aheadcluster"
  database_name                = "aheaddb"
  db_subnet_group_name         = aws_db_subnet_group.dbgroup.id
  deletion_protection          = false
  engine                       = "aurora-postgresql"
  engine_mode                  = "serverless"
  engine_version               = "10.14"
  kms_key_id                   = aws_kms_key.kms_key.arn
  master_username              = "ladberg"
  master_password              = random_password.password.result
  port                         = 5432
  preferred_backup_window      = "11:00-11:30"
  preferred_maintenance_window = "sat:04:00-sat:04:30"
  backup_retention_period      = 7
  skip_final_snapshot          = true
  copy_tags_to_snapshot        = true
  storage_encrypted            = true
  vpc_security_group_ids       = [aws_security_group.priv-sg.id]
  scaling_configuration {
    auto_pause               = false
    max_capacity             = 4
    min_capacity             = 2
    seconds_until_auto_pause = 300
    timeout_action           = "RollbackCapacityChange"
  }
  tags = {
    "Name" = "Ahead-db"
  }
}
