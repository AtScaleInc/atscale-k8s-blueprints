resource "azurerm_network_security_group" "postgres-nsg" {
  count               = var.enable_postgresql ? 1 : 0
  name                = "${var.environment}-postgres-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "vnet-access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "postgresql" {
  count                     = var.enable_postgresql ? 1 : 0
  subnet_id                 = azurerm_subnet.postgresql-subnet[0].id
  network_security_group_id = azurerm_network_security_group.postgres-nsg[0].id
}
