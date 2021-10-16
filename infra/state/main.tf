provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "site-state" {
  name = "galbitz-aws-state-db"
  hash_key = "LockID"
  read_capacity = 5
  write_capacity = 5

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_s3_bucket" "site-state" {
  bucket = "galbitz-aws-state-storage"
  acl    = "private"
}