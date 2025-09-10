output "server_fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "server_username" {
  value = azurerm_postgresql_flexible_server.this.administrator_login
}

output "server_password" {
  value = random_password.pass.result
}
