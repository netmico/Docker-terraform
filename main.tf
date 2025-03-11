provider "azurerm" {
  features {}
  subscription_id = ""
}

resource "azurerm_resource_group" "docker_rg" {
  name     = "docker-resource-group"
  location = "East US"
}

resource "azurerm_virtual_network" "docker_vnet" {
  name                = "docker-vnet"
  location            = azurerm_resource_group.docker_rg.location
  resource_group_name = azurerm_resource_group.docker_rg.name
  address_space       = ["10.93.0.0/16"]
}

resource "azurerm_subnet" "docker_subnet" {
  name                 = "docker-subnet"
  resource_group_name  = azurerm_resource_group.docker_rg.name
  virtual_network_name = azurerm_virtual_network.docker_vnet.name
  address_prefixes     = ["10.93.1.0/24"]
}

resource "azurerm_network_security_group" "docker_nsg" {
  name                = "docker-nsg"
  location            = azurerm_resource_group.docker_rg.location
  resource_group_name = azurerm_resource_group.docker_rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowDockerAPI"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2375"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "docker_nic" {
  name                = "docker-nic"
  location            = azurerm_resource_group.docker_rg.location
  resource_group_name = azurerm_resource_group.docker_rg.name

  ip_configuration {
    name                          = "docker-ip"
    subnet_id                     = azurerm_subnet.docker_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.docker_pip.id
  }
}

resource "azurerm_public_ip" "docker_pip" {
  name                = "docker-public-ip"
  location            = azurerm_resource_group.docker_rg.location
  resource_group_name = azurerm_resource_group.docker_rg.name
  allocation_method   = "Static"  # Change from "Dynamic" to "Static"
  sku                 = "Standard" # Keep or ensure this is "Standard"
}


resource "azurerm_linux_virtual_machine" "docker_vm" {
  name                = "docker-vm"
  resource_group_name = azurerm_resource_group.docker_rg.name
  location            = azurerm_resource_group.docker_rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.docker_nic.id
  ]

  admin_ssh_key {
  username   = "azureuser"
  public_key = file("C:/Users/Mario_pc/.ssh/id_ed25519.pub")
}



  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker azureuser
              EOF
  )
}

output "public_ip" {
  value = azurerm_public_ip.docker_pip.ip_address
}
