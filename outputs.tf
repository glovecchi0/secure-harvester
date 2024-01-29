output "harvester_url" {
  value = module.harvester-equinix.harvester_url
}

output "equinix_first_server_public_ip" {
  value = module.harvester-equinix.seed_ip
}

output "equinix_additional_servers_public_ip" {
  value = module.harvester-equinix.join_ips
}

output "neuvector-webui-url" {
  value       = "https://${module.harvester-equinix.seed_ip}:${data.kubernetes_service.neuvector-service-webui.spec.0.port.0.node_port}"
  description = "NeuVector WebUI (Console) URL"
}
