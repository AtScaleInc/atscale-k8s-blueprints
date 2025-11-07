output "server_fqdn" {
  value = azurerm_postgresql_flexible_server.this[0].fqdn
}

output "server_username" {
  value = azurerm_postgresql_flexible_server.this[0].administrator_login
}

output "server_password" {
  value = random_password.pass[0].result
}
