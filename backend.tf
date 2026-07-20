terraform {
  backend "s3" {
    bucket       = "<REPLACE-WITH-YOUR-EXISTING-BUCKET>"
    key          = "<REPLACE-WITH-YOUR-EXISTING-BUCKET-KEY>/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
