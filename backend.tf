terraform{
    backend "s3"{
        bucket = "terraform-state-lock-bucket-for-webapp"
        key ="terraform.tfstate"
        encrypt = true
        region = "us-east-1"

    }
}
