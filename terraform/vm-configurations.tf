variable "vm_configurations" {
  description = "Configuration for VMs"
  type = map(object({
    name     = string
    size     = string
    nic_name = string
    pip_name = string
  }))

  default = {
    vm1 = {
      name     = "NCas-T4-v3"
      size     = "Standard_NC4as_T4_v3"
      nic_name = "nic-NCas-T4-v3"
      pip_name = "pip-NCas-T4-v3"
    }
  }
}

# Create public IPs statically
resource "azurerm_public_ip" "pips" {
  for_each            = var.vm_configurations
  name                = each.value.pip_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

# Create network interfaces dynamically
resource "azurerm_network_interface" "nics" {
  for_each            = var.vm_configurations
  name                = each.value.nic_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pips[each.key].id
  }
}

# Associate the shared NSG with NICs
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  for_each                  = var.vm_configurations
  network_interface_id      = azurerm_network_interface.nics[each.key].id
  network_security_group_id = azurerm_network_security_group.shared_nsg.id
}

# Create Windows VMs dynamically
resource "azurerm_windows_virtual_machine" "vms" {
  for_each            = var.vm_configurations
  name                = each.value.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = each.value.size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nics[each.key].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "driver_extensions" {
  for_each                   = var.vm_configurations
  name                       = "${each.value.name}-driver"
  virtual_machine_id         = azurerm_windows_virtual_machine.vms[each.key].id
  publisher                  = "Microsoft.HpcCompute"
  type                       = "NvidiaGpuDriverWindows"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = false
  settings                   = <<SETTINGS
    {
      "InstallGridNC": "true"
    }
  SETTINGS
}

resource "azurerm_virtual_machine_extension" "custom_extension" {
  for_each             = var.vm_configurations
  name                 = "${each.value.name}-CustomExtension"
  virtual_machine_id   = azurerm_windows_virtual_machine.vms[each.key].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    "fileUris" : [
      "https://raw.githubusercontent.com/dr386/azure-gaming-desktop/master/setup.ps1"
    ],
    "commandToExecute" : "powershell.exe -ExecutionPolicy Unrestricted -File setup.ps1"
  })
}

