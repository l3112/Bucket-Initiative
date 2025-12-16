

# 1. Private S3 bucket
resource "aws_s3_bucket" "t0531M_Cl" {
  bucket = "my-private-bucket-example"

}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.t0531M_Cl.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload index.html
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.t0531M_Cl.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  acl          = "public-read"
}

# Upload style.css
resource "aws_s3_object" "style" {
  bucket       = aws_s3_bucket.t0531M_Cl.id
  key          = "style.css"
  source       = "${path.module}/style.css"
  content_type = "text/css"
  acl          = "public-read"
}

# 2. VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id          = "vpc-1234567890abcdef"
  service_name    = "com.amazonaws.us-east-1.s3"
  route_table_ids = ["rtb-1234567890abcdef"]
}

# 3. CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac"
  description                       = "Access control for S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 4. CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.t0531M_Cl.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# 5. Bucket Policy (restrict to VPC endpoint + CloudFront)
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.t0531M_Cl.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.t0531M_Cl.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.s3_endpoint.id
          }
        }
      }
    ]
  })
}
