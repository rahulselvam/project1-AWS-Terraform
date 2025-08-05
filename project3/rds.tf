resource "aws_db_instance" "mysql" {
  identifier              = "project3-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp2"
  username                = "admin"
  manage_master_user_password = true
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "project3-db-subnets"
  subnet_ids = module.vpc.database_subnets

  tags = {
    Name = "DB subnet group"
  }
}