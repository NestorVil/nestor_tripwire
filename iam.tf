data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ECS task execution role: pulls images, writes logs, injects secrets

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.name_prefix}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.laminar.arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name   = "read-laminar-secret"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets.json
}

# Data box role: SSM shell access, read the secret, write its logs

resource "aws_iam_role" "data_box" {
  name               = "${var.name_prefix}-data-box-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "data_box_ssm" {
  role       = aws_iam_role.data_box.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "data_box" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.laminar.arn]
  }

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.laminar["data-box"].arn}:*"]
  }
}

resource "aws_iam_role_policy" "data_box" {
  name   = "data-box-access"
  role   = aws_iam_role.data_box.id
  policy = data.aws_iam_policy_document.data_box.json
}

resource "aws_iam_instance_profile" "data_box" {
  name = "${var.name_prefix}-data-box-profile"
  role = aws_iam_role.data_box.name
}
