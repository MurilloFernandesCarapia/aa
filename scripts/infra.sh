#!/bin/bash
# =====================================================================
# PetCare360 - Script Azure CLI (Tarefa 01 do Challenge DevOps)
# =====================================================================
# 1.1 Provisiona uma VM Linux na Azure
# 1.2 Abre as portas necessarias ao projeto
# 1.3 Instala o Docker na VM
# 1.4 Instala as ferramentas necessarias (Git, nano)
# =====================================================================

# Configuracoes (mesmas da VM criada via portal Azure)
RG_NAME="rg-petcare360-devops"
LOCATION="southafricanorth"
VM_NAME="vm-petcare360"
VM_SIZE="Standard_D2s_v3"                                  # 2 vCPU, 8 GiB RAM
VM_IMAGE="Canonical:ubuntu-24_04-lts:server:latest"        # Ubuntu Server 24.04 LTS Gen2
ADMIN_USER="azureuser"
ADMIN_PASSWORD="PetCare@2026Devops"

# 1.1 - Provisionar VM Linux
az group create --name $RG_NAME --location $LOCATION

az vm create \
  --resource-group $RG_NAME \
  --name $VM_NAME \
  --image $VM_IMAGE \
  --size $VM_SIZE \
  --admin-username $ADMIN_USER \
  --admin-password $ADMIN_PASSWORD \
  --authentication-type password \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true \
  --public-ip-sku Standard \
  --nsg-rule SSH

# 1.2 - Abrir as portas necessarias ao projeto
NSG_NAME=$(az network nsg list --resource-group $RG_NAME --query "[0].name" -o tsv)

az network nsg rule create \
  --resource-group $RG_NAME \
  --nsg-name $NSG_NAME \
  --name Allow-API-8080 \
  --priority 1010 \
  --protocol Tcp \
  --destination-port-ranges 8080 \
  --access Allow

az network nsg rule create \
  --resource-group $RG_NAME \
  --nsg-name $NSG_NAME \
  --name Allow-Oracle-1521 \
  --priority 1020 \
  --protocol Tcp \
  --destination-port-ranges 1521 \
  --access Allow

# 1.3 e 1.4 - Instalar Docker, Git e nano na VM
az vm run-command invoke \
  --resource-group $RG_NAME \
  --name $VM_NAME \
  --command-id RunShellScript \
  --scripts "
    apt-get update -y
    apt-get install -y git nano curl ca-certificates gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo \$VERSION_CODENAME) stable\" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker $ADMIN_USER
  "

# Mostra o IP publico no final
az vm show --resource-group $RG_NAME --name $VM_NAME --show-details --query publicIps -o tsv