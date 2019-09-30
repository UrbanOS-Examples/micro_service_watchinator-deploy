# micro_service_watchinator-deploy
Deploy repository for micro_service_watchinator


# Deploying Via Terraform
```
env=dev
terraform init -backend-config=../common/backends/alm.conf
terraform workspace new $env
terraform plan --var-file=variables/$env.tfvars -var 'watchinator_image_name=199837183662.dkr.ecr.us-east-2.amazonaws.com/scos/micro-service-watchinator:<Image Tag>' --out=my.out
terraform apply my.out
```