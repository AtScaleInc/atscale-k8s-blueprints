resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.postgresql_version
  sku_name                      = var.sku_name
  administrator_login           = var.administrator_login
  administrator_password        = random_password.pass.result
  zone                          = "1"
  storage_mb                    = var.storage_mb
  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = var.geo_redundant_backup_enabled
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false
}

resource "random_password" "pass" {
  length  = 16
  special = false
}

resource "azurerm_postgresql_flexible_server_configuration" "pgbouncer" {

  name      = "pgbouncer.enabled"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "true"
}
