terraform {
  backend "s3" {
    bucket         = "${bucket}"
    key            = "${key != null ? key : "terraform.tfstate"}"
    region         = "${region}"
    dynamodb_table = "${dynamodb_table}"
    encrypt        = true
  }
}