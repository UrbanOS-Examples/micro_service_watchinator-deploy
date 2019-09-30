data "terraform_remote_state" "env_remote_state" {
  backend   = "s3"
  workspace = "${terraform.workspace}"

  config {
    bucket   = "${var.alm_state_bucket_name}"
    key      = "operating-system"
    region   = "us-east-2"
    role_arn = "${var.alm_role_arn}"
  }
}

resource "local_file" "kubeconfig" {
  filename = "${path.module}/outputs/kubeconfig"
  content  = "${data.terraform_remote_state.env_remote_state.eks_cluster_kubeconfig}"
}

resource "local_file" "helm_vars" {
  filename = "${path.module}/outputs/${terraform.workspace}.yaml"

  content = <<EOF
CONSUMER_URI: wss://streams.${data.terraform_remote_state.env_remote_state.dns_zone_name}/socket/websocket
image:
  repository: ${var.image_repository}
  tag: ${var.tag}
EOF
}

resource "null_resource" "helm_deploy" {
  provisioner "local-exec" {
    command = <<EOF
export KUBECONFIG=${local_file.kubeconfig.filename}

export AWS_DEFAULT_REGION=us-east-2
helm repo add scdp https://smartcitiesdata.github.io/charts
helm repo update
helm upgrade --install ${var.watchinator_deploy_name} scdp/micro-service-watchinator --namespace=watchinator \
     --version ${var.chartVersion} \
    --values ${local_file.helm_vars.filename} \
    --values micro-service-watchinator.yaml \
      ${var.extraHelmCommandArgs}
EOF
  }

  triggers {
    # Triggers a list of values that, when changed, will cause the resource to be recreated
    # ${uuid()} will always be different thus always executing above local-exec
    hack_that_always_forces_null_resources_to_execute = "${uuid()}"
  }
}

variable "alm_role_arn" {
  description = "The ARN for the assume role for ALM access"
  default     = "arn:aws:iam::199837183662:role/jenkins_role"
}

variable "alm_state_bucket_name" {
  description = "The name of the S3 state bucket for ALM"
  default     = "scos-alm-terraform-state"
}

variable "watchinator_deploy_name" {
  description = "The helm deploy name to give to the watchinator"
  default     = "watchinator"
}

variable "image_repository" {
  description = "The image repository"
  default     = "199837183662.dkr.ecr.us-east-2.amazonaws.com/scos/micro-service-watchinator"
}

variable "tag" {
  description = "The tag/version of the image to deploy"
  default     = "latest"
}

variable "extraHelmCommandArgs" {
  description = "Extra command arguments that will be passed to helm upgrade command"
  default     = ""
}

variable "chartVersion" {
  description = "Version of the chart to deploy"
  default     = "1.0.0"
}
