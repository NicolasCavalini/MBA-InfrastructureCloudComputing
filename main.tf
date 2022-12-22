terraform{
    required_version = " >= 0.13"
 
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = ">= 2.26"
        }
    }
}

provider "azurerm" {
    features{}
}

resource "azurerm_resource_group" "rg-atividadeinfra" {
  name     = "atividadeinfraterra"
  location = "centralus"
}

resource "azurerm_virtual_network" "vnet-atividadeinfra" {
  name                = "vnet"
  location            = azurerm_resource_group.rg-atividadeinfra.location
  resource_group_name = azurerm_resource_group.rg-atividadeinfra.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
    turma = "TFS-04"
    faculdade = "Impacta Tecnologia"
    aluno = "Nicolas"
    professor = "João"
  }
}

resource "azurerm_subnet" "subatividadeinfra" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg-atividadeinfra.name
  virtual_network_name = azurerm_virtual_network.vnet-atividadeinfra.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ipatividadeinfra" {
  name                    = "publicIp"
  location                = azurerm_resource_group.rg-atividadeinfra.location
  resource_group_name     = azurerm_resource_group.rg-atividadeinfra.name
  allocation_method       = "Static"
}

resource "azurerm_network_security_group" "nsgatividadeinfra" {
  name                = "nsg"
  location            = azurerm_resource_group.rg-atividadeinfra.location
  resource_group_name = azurerm_resource_group.rg-atividadeinfra.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

   security_rule {
    name                       = "Web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
  faculdade = "Impacta Tecnologia"
  }
}

resource "azurerm_network_interface" "nicatividadeinfra" {
  name                = "nic"
  location            = azurerm_resource_group.rg-atividadeinfra.location
  resource_group_name = azurerm_resource_group.rg-atividadeinfra.name

  ip_configuration {
    name                          = "nic-ip"
    subnet_id                     = azurerm_subnet.subatividadeinfra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.ipatividadeinfra.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-atividadeinfra" {
  network_interface_id      = azurerm_network_interface.nicatividadeinfra.id
  network_security_group_id = azurerm_network_security_group.nsgatividadeinfra.id
}

resource "azurerm_storage_account" "saatividadeinfra" {
  name                     = "saatividadeinfra"
  resource_group_name      = azurerm_resource_group.rg-atividadeinfra.name
  location                 = azurerm_resource_group.rg-atividadeinfra.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
   faculdade = "Impacta Tecnologia"
  }
}

resource "azurerm_linux_virtual_machine" "vmatividadeinfra" {
  name                = "myvm"
  resource_group_name = azurerm_resource_group.rg-atividadeinfra.name
  location            = azurerm_resource_group.rg-atividadeinfra.location
  size                = "Standard_D2ads_v5"

  network_interface_ids = [
    azurerm_network_interface.nicatividadeinfra.id
  ]

    admin_username = var.user
    admin_password = var.password
    disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    name = "mydisk"
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.saatividadeinfra.primary_blob_endpoint
  }

}

data "azurerm_public_ip" "ipatividadeinfradata"{
  name = azurerm_public_ip.ipatividadeinfra.name
  resource_group_name = azurerm_resource_group.rg-atividadeinfra.name
}

variable "user" {
  description = "Usuário"
  type= string 
}

variable "password"{
 description = "Senha"
  type= string 
}

resource "null_resource" "install-webserver" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ipatividadeinfradata.ip_address
    user = var.user
    password= var.password
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.vmatividadeinfra
  ]
  
}