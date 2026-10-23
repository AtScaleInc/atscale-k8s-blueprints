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

# Every subnet gets an NSG: the "Subnets should be associated with a Network
# Security Group" policy is common in enterprise subscriptions. The Azure
# default rules still apply below these: VNet-to-VNet traffic, the
# AzureLoadBalancer health probes and outbound traffic stay allowed, and
# everything else inbound is denied.
#
# This NSG sits on the subnet, in front of the one AKS manages on the node
# NICs, so traffic to a LoadBalancer Service must pass both. AKS does not add
# rules here, hence the explicit allow for the AtScale ports (HTTP/HTTPS
# through the proxy and pgwire 15432).
resource "azurerm_network_security_group" "aks-nsg" {
  name                = "${var.environment}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = var.atscale_allowed_source_prefixes
    content {
      name                       = "atscale-inbound-${security_rule.key}"
      priority                   = 100 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = var.atscale_ports
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks-subnet.id
  network_security_group_id = azurerm_network_security_group.aks-nsg.id
}

# Application Gateway for Containers enforces NSG rules on the association
# subnet (for associations created since April 2026), so its listeners need
# an explicit allow. It only serves HTTP/HTTPS.
resource "azurerm_network_security_group" "alb-nsg" {
  count               = var.enable_ingress_gateway ? 1 : 0
  name                = "${var.environment}-alb-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = var.atscale_allowed_source_prefixes
    content {
      name                       = "https-inbound-${security_rule.key}"
      priority                   = 100 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["80", "443"]
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet_network_security_group_association" "alb" {
  count                     = var.enable_ingress_gateway ? 1 : 0
  subnet_id                 = azurerm_subnet.alb-subnet[0].id
  network_security_group_id = azurerm_network_security_group.alb-nsg[0].id
}
