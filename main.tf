locals {
  service_account_name = coalesce(var.deployment_name, module.this.id, "tfc-agent")
  deployment_name      = coalesce(var.deployment_name, module.this.id, "tfc-agent")

  namespace = coalesce(var.kubernetes_namespace, "default")
}

resource "kubernetes_namespace" "namespace" {
  count = var.namespace_creation_enabled ? 1 : 0
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_service_account" "service_account" {
  count = module.this.enabled ? 1 : 0

  metadata {
    name        = local.service_account_name
    namespace   = local.namespace
    annotations = var.service_account_annotations
  }
}

resource "kubernetes_secret" "secret" {
  metadata {
    name      = local.deployment_name
    namespace = local.namespace
  }

  data = {
    token = var.tfc_agent_token
  }
}

resource "kubernetes_deployment" "tfc_cloud_agent" {
  count = module.this.enabled ? 1 : 0

  metadata {
    name      = local.deployment_name
    namespace = local.namespace
    labels    = module.this.tags
  }
  spec {
    selector {
      match_labels = module.this.tags
    }
    replicas = var.replicas

    template {
      metadata {
        namespace   = local.namespace
        labels      = module.this.tags
        annotations = var.deployment_annotations
      }
      spec {
        service_account_name            = local.service_account_name
        automount_service_account_token = true
        container {
          image = var.agent_image
          name  = "tfc-agent"
          args  = var.agent_cli_args
          env {
            name = "TFC_AGENT_TOKEN"
            value_from {
              secret_key_ref {
                key  = "token"
                name = local.deployment_name
              }
            }
          }
          env {
            name  = "TFC_AGENT_NAME"
            value = coalesce(module.this.id, "tfc-agent")
          }
          env {
            name  = "TFC_AGENT_LOG_LEVEL"
            value = var.tfc_agent_log_level
          }
          env {
            name  = "TFC_AGENT_SINGLE"
            value = var.tfc_agent_single
          }
          env {
            name  = "TFC_AGENT_AUTO_UPDATE"
            value = var.tfc_agent_auto_update
          }
          env {
            name  = "TFC_ADDRESS"
            value = var.tfc_address
          }
          dynamic "env" {
            for_each = var.tfc_agent_data_dir == null ? [] : [1]
            content {
              name  = "TFC_AGENT_DATA_DIR"
              value = var.tfc_agent_data_dir
            }
          }
          dynamic "env" {
            for_each = var.agent_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          resources {
            limits = {
              cpu    = var.resource_limits_cpu
              memory = var.resource_limits_memory
            }
            requests = {
              cpu    = var.resource_requests_cpu
              memory = var.resource_requests_memory
            }
          }
        }
      }
    }
  }
}
