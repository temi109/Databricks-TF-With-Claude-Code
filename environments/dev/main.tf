module "s3_bucket" {
  source = "../../modules/s3"

  bucket_name   = "ti-test-bucket-tf-1"
  environment   = var.environment
  force_destroy = var.force_destroy
}
