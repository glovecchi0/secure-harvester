locals {
  private_ssh_key_path = fileexists("${path.cwd}/${var.prefix}-ssh_private_key.pem") ? "${path.cwd}/${var.prefix}-ssh_private_key.pem" : var.ssh_private_key_path
  public_ssh_key_path  = fileexists("${path.cwd}/${var.prefix}-ssh_public_key.pem") ? "${path.cwd}/${var.prefix}-ssh_public_key.pem" : var.ssh_public_key_path
}

module "harvester-equinix" {
  source       = "git::https://github.com/glovecchi0/neuvector-tf.git//tf-modules/harvester/infrastructure/equinix"
  prefix       = var.prefix
  project_name = var.project_name
  metro        = var.metro
}

resource "null_resource" "wait-harvester-services-startup" {
  depends_on = [module.harvester-equinix]
  provisioner "local-exec" {
    command     = <<-EOF
      count=0
      while [ "$${count}" -lt 15 ]; do
        resp=$(curl -k -s -o /dev/null -w "%%{http_code}" $${HARVESTER_URL}ping)
        echo "Waiting for $${HARVESTER_URL}ping - response: $${resp}"
        if [ "$${resp}" = "200" ]; then
          ((count++))
        fi
        sleep 2
      done
      EOF
    interpreter = ["/bin/bash", "-c"]
    environment = {
      HARVESTER_URL = module.harvester-equinix.harvester_url
    }
  }
}

data "local_file" "ssh-private-key" {
  depends_on = [module.harvester-equinix]
  filename   = local.private_ssh_key_path
}

data "local_file" "ssh-public-key" {
  depends_on = [module.harvester-equinix]
  filename   = local.public_ssh_key_path
}

locals {
  kc_path = var.kube_config_path != null ? var.kube_config_path : path.cwd
  kc_file = var.kube_config_filename != null ? "${local.kc_path}/${var.kube_config_filename}" : "${local.kc_path}/${var.prefix}_kube_config.yml"
}

resource "ssh_resource" "retrieve-kubeconfig" {
  depends_on = [data.local_file.ssh-private-key]
  host       = module.harvester-equinix.seed_ip
  commands = [
    "sudo sed 's/127.0.0.1/${module.harvester-equinix.seed_ip}/g' /etc/rancher/rke2/rke2.yaml"
  ]
  user        = "rancher"
  private_key = data.local_file.ssh-private-key.content
}

resource "local_file" "kubeconfig-yaml" {
  depends_on      = [ssh_resource.retrieve-kubeconfig]
  filename        = local.kc_file
  file_permission = "0600"
  content         = ssh_resource.retrieve-kubeconfig.result
}

resource "helm_release" "neuvector-core" {
  depends_on       = [local_file.kubeconfig-yaml]
  name             = "neuvector"
  repository       = "https://neuvector.github.io/neuvector-helm/"
  chart            = "core"
  create_namespace = true
  namespace        = "cattle-neuvector-system"

  set {
    name  = "k3s.enabled"
    value = "true"
  }

  set {
    name  = "rbac"
    value = "false"
  }

  set {
    name  = "manager.svc.type"
    value = "NodePort"
  }

  set {
    name = "controller.secret.enabled"
    value = "true"
  }

  set {
    name  = "controller.secret.data.userinitcfg\\.yaml.users[0].Password"
    value = var.neuvector_password
  }
}

data "kubernetes_service" "neuvector-service-webui" {
  metadata {
    name      = "neuvector-service-webui"
    namespace = resource.helm_release.neuvector-core.namespace
  }
}
