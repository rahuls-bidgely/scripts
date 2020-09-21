provider "aws" {
  region                  = "us-west-2"
  shared_credentials_file = "/home/rahul-optit/.aws/credentials"
  profile                 = "nonprodqa"
}

resource "aws_sns_topic" "topic" {
  name = "NSMDisaggReadyUsersPriority-uat-pp"
}

resource "aws_sns_topic_subscription" "topic_lambda" {
  topic_arn = "${aws_sns_topic.topic.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.lambda.arn}"
}

resource "aws_lambda_function" "lambda" {
  function_name = "NSMDisaggPriority-uat-pp"
  s3_bucket     = "bidgely-artifacts2"
  s3_key        = "zips/rmp/nsm-1.sakshi-NSMDisagg.303.zip"
  role          = "arn:aws:iam::189675173661:role/lamda-ec2-ami-role"
  handler       = "nsm_lambda.lambda_handler"
  runtime       = "python3.6"
  timeout       = 300
  memory_size   = 1024



}

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.topic.arn}"
}
