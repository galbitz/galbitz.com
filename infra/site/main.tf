provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">=0.12.19"
  backend "s3" {
    encrypt        = true
    bucket         = "galbitz-aws-state-storage"
    dynamodb_table = "galbitz-aws-state-db"
    key            = "galbitz/terraform.tfstate"
    region         = "us-east-1"
  }
}

resource "aws_s3_bucket" "static-site" {
  bucket = "${var.domain_name}-storage"
  acl    = "private"
  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  force_destroy = true
}
#cert

resource "aws_acm_certificate" "static-site" {
  domain_name       = var.domain_name
  subject_alternative_names = var.subject_names
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "static-site" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "static-site" {
  for_each = {
    for dvo in aws_acm_certificate.static-site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.static-site.zone_id
}

resource "aws_acm_certificate_validation" "static-site" {
  certificate_arn         = aws_acm_certificate.static-site.arn
  validation_record_fqdns = [for record in aws_route53_record.static-site : record.fqdn]
}

#cloudfront
resource "aws_cloudfront_origin_access_identity" "static-site" {
  comment = "bucket access identity"
}

resource "aws_cloudfront_distribution" "static-site" {
  origin {
    domain_name = aws_s3_bucket.static-site.bucket_regional_domain_name
    origin_id   = var.domain_name
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.static-site.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"
  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.domain_name
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  aliases = var.subject_names

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.static-site.arn
    ssl_support_method  = "sni-only"
  }

#   price_class = "PriceClass_100"
}


data "aws_iam_policy_document" "static-site" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static-site.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.static-site.iam_arn}"]
    }
  }
}
resource "aws_s3_bucket_policy" "static-site" {
  bucket = aws_s3_bucket.static-site.id
  policy = data.aws_iam_policy_document.static-site.json
}

resource "aws_route53_record" "static-site-record" {
  zone_id = data.aws_route53_zone.static-site.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static-site.domain_name
    zone_id                = aws_cloudfront_distribution.static-site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "static-site-record-2" {
  zone_id = data.aws_route53_zone.static-site.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static-site.domain_name
    zone_id                = aws_cloudfront_distribution.static-site.hosted_zone_id
    evaluate_target_health = false
  }
}