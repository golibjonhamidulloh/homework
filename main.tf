provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "my_instance" {
  ami           = "ami-089c26792dcb1fbd4"
  instance_type = "t2.micro"

  tags = {
    Name = "MyEC2Instance"
  }
}


resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
}


data "archive_file" "lambda" {
  type        = "zip"
  source_file = "shutdown_instance.py"
  output_path = "shutdown_instance.zip"
}

resource "aws_lambda_function" "shutdown_instance" {

  filename      = data.archive_file.lambda.output_path
  function_name = "shutdown_instance"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "shutdown_instance.lambda_handler"
  runtime = "python3.11"
}


####### Now let's set up the CloudWatch Events rule to trigger the Lambda function #########


resource "aws_cloudwatch_event_rule" "schedule_shutdown" {
  name                = "ScheduleShutdown"
  schedule_expression = "cron(0 15 * * ? *)"
}

resource "aws_cloudwatch_event_target" "shutdown_target" {
  rule      = aws_cloudwatch_event_rule.schedule_shutdown.name
  target_id = "ShutdownInstance"
  arn       = aws_lambda_function.shutdown_instance.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_shutdown" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.shutdown_instance.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule_shutdown.arn
}




