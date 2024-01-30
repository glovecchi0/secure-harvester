# Secure Harvester

Secure your Harvester cluster by installing NeuVector on the underlying infrastructure.

**This project aims to show how to secure and monitor the infrastructure underlying the Harvester cluster. Therefore, we can reuse the Harvester-Equinix Terraform modules from the [neuvector-tf repository](https://github.com/glovecchi0/neuvector-tf/tree/main/tf-modules/harvester/infrastructure).**

## How to create resources

- Copy `./terraform.tfvars.example` to `./terraform.tfvars`
- Edit `./terraform.tfvars`
  - Update the required variables:
    -  `prefix` to give the resources an identifiable name (eg, your initials or first name)
    -  `project_name` to specify in which Project the resources will be created
    -  `metro` to suit your Region
    -  `neuvector_password` to change the default admin password
- Make sure you are logged into your Equinix Account from your local Terminal. See the preparatory steps [here](../../../tf-modules/harvester/infrastructure/README.md).

```bash
terraform init -upgrade ; terraform apply -target=module.harvester-equinix.tls_private_key.ssh_private_key -target=module.harvester-equinix.local_file.private_key_pem -target=module.harvester-equinix.local_file.public_key_pem -auto-approve ; terraform apply -target=module.harvester-equinix -target=null_resource.wait-harvester-services-startup -auto-approve ; terraform apply -target=local_file.ssh-private-key -target=ssh_resource.retrieve-kubeconfig -target=local_file.kubeconfig-yaml -auto-approve ; terraform apply -auto-approve
```

**Check the output of the `terraform apply` command to get the Harvester and NeuVector URLs.**

- Destroy the resources when finished
```bash
terraform destroy -auto-approve
```

## How to access Equinix instances

#### Add your PUBLIC SSH Key to your Equinix profile (Click at the top right > My Profile > SSH Keys > + Add New Key)

#### Run the following command

```bash
ssh -oStrictHostKeyChecking=no -i <PREFIX>-ssh_private_key.pem rancher@<PUBLIC_IPV4>
```

## How to manage NeuVector resources

```bash
export KUBECONFIG=<PREFIX>_kube_config.yml
kubectl -n cattle-neuvector-system get pods,services
```
