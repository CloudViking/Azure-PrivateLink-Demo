##############################################################################################################
##############################################################################################################
#
#   Create new Private Link Service
#
##############################################################################################################
##############################################################################################################

# Importing Variables
set -a 
. ./config.sh
set +a

# Create Private Link Resource Group
echo "Creating PL Resource Group..."
az group create \
    --name $pl_rg_name \
    --location $location

# Create PL Vnet
echo "Creating PL Vnet: 172.16.0.0/16"
az network vnet create \
    --resource-group $pl_rg_name \
    --name PLVnet \
    --address-prefix 172.16.0.0/16

# New Private Link Service (PLS) Subnet
echo "Creating PLS subnet..."
az network vnet subnet create \
    --resource-group $pl_rg_name \
    --vnet-name PLVnet \
    --name PLS-Subnet \
    --address-prefixes 172.16.0.0/24

# New PLS Load Balancer
echo "Creating PLS Internal Load Balancer..."
az network lb create \
    --resource-group $pl_rg_name \
    --name myILB \
    --sku standard \
    --vnet-name PLVnet \
    --subnet PLS-Subnet \
    --frontend-ip-name myFrontEnd \
    --backend-pool-name myBackEndPool

# PLS LB Health Probe
echo "Creating LB Health Probe..."
az network lb probe create \
    --resource-group $pl_rg_name \
    --lb-name myILB \
    --name myHealthProbe \
    --protocol tcp \
    --port 80

# PLS LB Rule
echo "Creating LB Rule..."
az network lb rule create \
    --resource-group $pl_rg_name \
    --lb-name myILB \
    --name myHTTPRule \
    --protocol tcp \
    --frontend-port 80 \
    --backend-port 80 \
    --frontend-ip-name myFrontEnd \
    --backend-pool-name myBackEndPool \
    --probe-name myHealthProbe

# PLS NSG
echo "Creating NSG"
az network nsg create \
    --resource-group $pl_rg_name \
    --name PL-NSG

# PLS NSG Rule
echo "Creating NSG Rule"
az network nsg rule create \
    --resource-group $pl_rg_name \
    --nsg-name PL-NSG \
    --name HttpRule \
    --protocol tcp \
    --direction inbound \
    --source-address-prefix '*' \
    --source-port-range '*' \
    --destination-address-prefix '*' \
    --destination-port-range 80 \
    --access allow \
    --priority 200

# Disable Private link Network Policies on Subnet
echo "Disabling network policies on PLS subnet"
az network vnet subnet update \
--resource-group $pl_rg_name \
--vnet-name PLVnet \
--name PLS-Subnet \
--disable-private-link-service-network-policies true

# Create Private Link Service
echo "Creating Private Link Service..."
az network private-link-service create \
--resource-group $pl_rg_name \
--name myPLS \
--vnet-name PLVnet \
--subnet PLS-Subnet \
--lb-name myILB \
--lb-frontend-ip-configs myFrontEnd \
--location $location

PLSid=$(az network private-link-service show -g $pl_rg_name -n myPLS | jq .id -r)
echo "Private Link Service has been created. \
    Service-Id: $PLSid"
