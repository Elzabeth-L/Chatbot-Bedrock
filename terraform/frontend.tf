resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "${local.name_prefix}-frontend-"
  force_destroy = var.force_destroy_buckets
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name_prefix}-oac"
  description                       = "Signed access to the private frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${local.name_prefix}-security-headers"
  security_headers_config {
    content_security_policy {
      # The API itself is origin-restricted to this distribution. Using https: here
      # avoids a CloudFront -> API -> CloudFront creation cycle.
      content_security_policy = "default-src 'self'; connect-src 'self' https:; img-src 'self' data:; style-src 'self'; script-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"
      override                = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = false
      override                   = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  comment             = "${local.name_prefix} private frontend"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "frontend-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    target_origin_id           = "frontend-s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD", "OPTIONS"]
    compress                   = true
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # CloudFront fixes its default *.cloudfront.net certificate policy to TLSv1.
    # A custom domain/certificate is required to select TLSv1.2_2021.
    minimum_protocol_version = "TLSv1"
  }
}

data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.frontend.arn, "${aws_s3_bucket.frontend.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
  statement {
    sid       = "AllowCloudFrontReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket.json
}

resource "aws_s3_object" "frontend_index" {
  bucket                 = aws_s3_bucket.frontend.id
  key                    = "index.html"
  source                 = "${path.module}/../frontend/index.html"
  etag                   = filemd5("${path.module}/../frontend/index.html")
  content_type           = "text/html; charset=utf-8"
  cache_control          = "no-cache"
  server_side_encryption = "AES256"
}

resource "aws_s3_object" "frontend_styles" {
  bucket                 = aws_s3_bucket.frontend.id
  key                    = "styles.css"
  source                 = "${path.module}/../frontend/styles.css"
  etag                   = filemd5("${path.module}/../frontend/styles.css")
  content_type           = "text/css; charset=utf-8"
  cache_control          = "public,max-age=3600"
  server_side_encryption = "AES256"
}

resource "aws_s3_object" "frontend_app" {
  bucket                 = aws_s3_bucket.frontend.id
  key                    = "app.js"
  source                 = "${path.module}/../frontend/app.js"
  etag                   = filemd5("${path.module}/../frontend/app.js")
  content_type           = "application/javascript; charset=utf-8"
  cache_control          = "no-cache"
  server_side_encryption = "AES256"
}

resource "aws_s3_object" "frontend_config" {
  bucket                 = aws_s3_bucket.frontend.id
  key                    = "config.js"
  content                = templatefile("${path.module}/../frontend/config.js.tftpl", { api_url = aws_apigatewayv2_api.chat.api_endpoint })
  content_type           = "application/javascript; charset=utf-8"
  cache_control          = "no-store"
  server_side_encryption = "AES256"
}
