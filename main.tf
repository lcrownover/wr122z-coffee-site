locals {
  backend_bucket    = "uo-lcrown-tfstate"
  bucket_lock_table = "coffee-site-tfstate-lock"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
  backend "s3" {
    bucket         = local.backend_bucket
    key            = "terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = local.bucket_lock_table
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "site" {
  bucket_prefix = "coffee-site"

  tags = {
    Name        = "wr122z coffee site"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.bucket

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.site.bucket
  key          = "index.html"
  source       = "index.html"
  etag         = filemd5("index.html")
  content_type = "text/html"
}
resource "aws_s3_object" "images" {
  for_each = fileset(path.module, "images/*.jpg")

  bucket = aws_s3_bucket.site.bucket
  key    = each.value
  source = "${path.module}/${each.value}"
  etag = filemd5("${path.module}/${each.value}")
}
output "fileset-results" {
  value = fileset(path.module, "images/*.jpg")
}


resource "aws_s3_bucket_policy" "public_access" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.public_access.json
}

data "aws_iam_policy_document" "public_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.site.bucket}/*"
    ]
  }
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  routing_rule {
    condition {
      key_prefix_equals = "/"
    }
    redirect {
      replace_key_prefix_with = "index.html"
    }
  }
}

