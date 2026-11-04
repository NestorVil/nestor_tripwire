locals {
  data_box_images = {
    clickhouse = "clickhouse/clickhouse-server:26.10.3.7@sha256:739e099abd1157390960a59e4532d21781d8fde57e6e4151cb920ea02c30b1ce"
    valkey     = "valkey/valkey:9.1"
    rabbitmq   = "rabbitmq:4.3.7"
    quickwit   = "quickwit/quickwit:v0.9.1"
  }

  # Laminar's ClickHouse config files at commit ae5c7d1a2 (v0.3.2)
  laminar_config_sha256 = {
    "clickhouse/lmnr-server.xml"   = "ab8ae9e3707323e846b75a8b3881ea8f37850ddba4c6675a6cbdf05c0fc72969"
    "clickhouse/lmnr-profiles.xml" = "7cac53a693010ff5cf6f3258952f39afba7857f1858eec83684ca703a8bfe006"
  }
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_ebs_volume" "data" {
  availability_zone = aws_subnet.private["a"].availability_zone
  size              = 30
  type              = "gp3"
  encrypted         = true

  tags = {
    Name   = "${var.name_prefix}-data"
    Backup = "${var.name_prefix}-data-box"
  }
}

resource "aws_instance" "data_box" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.insecure_value
  instance_type          = "t4g.large"
  subnet_id              = aws_subnet.private["a"].id
  vpc_security_group_ids = [aws_security_group.data.id]
  iam_instance_profile   = aws_iam_instance_profile.data_box.name

  user_data = templatefile("${path.module}/templates/data_box.sh.tftpl", {
    data_volume_serial = replace(aws_ebs_volume.data.id, "-", "")
    region             = data.aws_region.current.region
    secret_arn         = aws_secretsmanager_secret.laminar.arn
    log_group          = aws_cloudwatch_log_group.laminar["data-box"].name
    images             = local.data_box_images
    config_files = {
      clickhouse_lmnr_server       = filebase64("${path.module}/files/clickhouse/lmnr-server.xml")
      clickhouse_lmnr_profiles     = filebase64("${path.module}/files/clickhouse/lmnr-profiles.xml")
      clickhouse_tripwire_server   = filebase64("${path.module}/files/clickhouse/tripwire-server.xml")
      clickhouse_tripwire_profiles = filebase64("${path.module}/files/clickhouse/tripwire-profiles.xml")
      rabbitmq                     = filebase64("${path.module}/files/rabbitmq/20-tripwire.conf")
      quickwit                     = filebase64("${path.module}/files/quickwit/quickwit.yaml")
    }
  })

  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.name_prefix}-data-box" }

  lifecycle {
    ignore_changes = [ami]

    precondition {
      condition = alltrue([
        for file_name, expected_sha256 in local.laminar_config_sha256 :
        filesha256("${path.module}/files/${file_name}") == expected_sha256
      ])
      error_message = "Laminar's ClickHouse config files in files/clickhouse/ don't match commit ae5c7d1a2."
    }
  }
}

resource "aws_volume_attachment" "data" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.data.id
  instance_id                    = aws_instance.data_box.id
  stop_instance_before_detaching = true
}
