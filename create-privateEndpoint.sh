##############################################################################################################
##############################################################################################################
#
#   Create new Private Link Endpoints
#
##############################################################################################################
##############################################################################################################

# Importing Variables
set -a 
. ./config.sh
set +a

# Grab PLS ID
PLSid=$(az network private-link-service show -g $pl_rg_name -n myPLS | jq .id -r)
echo "PrivateLinkService-id: $PLSid"

for i in `seq $num_of_pe`; do
    # Create Private Endpoint Resource Groups
    echo "Creating PE Resource Group: $pe_rg_prefix-$i"
    az group create \
        --name $pe_rg_prefix-$i \
        --location $location

    # Create PL Vnet
    echo "Creating PE Vnet: PE-Vnet-$i"
    az network vnet create \
        --resource-group $pe_rg_prefix-$i \
        --name PE-Vnet-$i \
        --address-prefix 10.2.0.0/16

    # Create PE Subnet
    echo "Creating Private EndPoint subnet: PE-Subnet-$i"
    az network vnet subnet create \
        --resource-group $pe_rg_prefix-$i \
        --vnet-name PE-Vnet-$i \
        --name PE-Subnet-$i \
        --address-prefixes 10.2.0.0/24

    # Create VM's to test Private Link and App.
    if [ -z $windows_test ]; then
        windows_test="false"
        echo "No Windows test VM will be deployed"
    fi

    if [ $windows_test == "true" ]; then 
        echo "Creating Windows Test VM in Resource Group: $pe_rg_prefix-$i"
        az vm create \
            --resource-group $pe_rg_prefix-$i \
            --name WinVMTest-rg$i \
            --image win2016datacenter \
            --vnet-name PE-Vnet-$i \
            --subnet PE-Subnet-$i \
            --admin-username $admin_username \
            --admin-password $admin_password
    fi

    if [ -z $linux_test ]; then
        linux_test="false"
        echo "No Linux test VM will be deployed"
    fi
    
    if [ $linux_test == "true" ]; then
        echo "Creating Linux Test VM in RG: $pe_rg_prefix-$i"
        az vm create \
            --resource-group $pe_rg_prefix-$i \
            --name LinVMTest-rg$i \
            --image UbuntuLTS \
            --vnet-name PE-Vnet-$i \
            --subnet PE-Subnet-$i \
            --ssh-key-values $ssh_key_path \
            --custom-data cloud-init.txt
    else 
        echo "No test VM being deployed. There was no option selected in config.sh"
    fi

    # Disable network policies
    echo "Disabling network policies on PE subnet: PE-Subnet-$i"
    az network vnet subnet update \
        --resource-group $pe_rg_prefix-$i \
        --vnet-name PE-Vnet-$i \
        --name PE-Subnet-$i \
        --disable-private-endpoint-network-policies true

    # Create Private Endpoint and connecting to the Private Link Service
    echo "Creating Private Endpoint and connecting to the Private Link Service..."
    az network private-endpoint create \
        --resource-group $pe_rg_prefix-$i \
        --name myPrivateEndpoint \
        --vnet-name PE-Vnet-$i \
        --subnet PE-Subnet-$i \
        --private-connection-resource-id $PLSid \
        --connection-name PEConnectingPLS \
        --location $location

    echo "Success!!! Private Link Service connection has been established in RG: $pe_rg_prefix-$i" 
    echo "Please validate the connection by logging into test VM, if deployed."
done