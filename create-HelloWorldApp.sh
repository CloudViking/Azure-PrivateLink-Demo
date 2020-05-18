##############################################################################################################
##############################################################################################################
#
#   Create new Node Webb App 
#
##############################################################################################################
##############################################################################################################

# Import Variables
set -a 
. ./config.sh
set +a

# Create Availability Set
echo "Creating Availability set for WebApp VM's"
az vm availability-set create \
    --resource-group $pl_rg_name \
    --name WebAppAvailabilitySet

# Create all WebApp VM infrastructure
for i in `seq 3`; do

    # Create 3 PIP's to bootstrap VM's
    echo "Creating Public IP: myPIP-$i"
    az network public-ip create \
        --name myPIP-$i \
        --resource-group $pl_rg_name

    # Create NIC's for Service/App VM's
    echo "Creating VM NIC: myNic-$i"
    az network nic create \
        --resource-group $pl_rg_name \
        --name myNic-$i \
        --network-security-group PL-NSG \
        --vnet-name PLVnet \
        --subnet PLS-Subnet \
        --public-ip-address myPIP-$i

    # Create App VM's
    echo "Creating WebApp VM: myWebAppVM-$i"
    az vm create \
        --resource-group $pl_rg_name \
        --name myWebAppVM-$i \
        --image UbuntuLTS \
        --nics myNIC-$i \
        --availability-set WebAppAvailabilitySet \
        --custom-data cloud-init.txt \
        --admin-username $admin_username \
        --admin-password $admin_password

done
echo "All WebApp VM's have been deployed"

# Wait until packages are installed and app has started, then delete public ip
echo "Waiting until app is ready... then disassociate, and delete, public ip"
for i in `seq 3`; do
    
    pip=$(az network public-ip show --resource-group $pl_rg_name --name myPIP-$i | jq .ipAddress -r)
    echo "myPIP-$i= $pip"
    
    httpResponse=$(curl -s -o /dev/null -w "%{http_code}" http://$pip)
    until [ $httpResponse -eq "200" ]; do
        httpResponse=$(curl -s -o /dev/null -w "%{http_code}" http://$pip)
        echo "HTTP response: $httpResponse"
        sleep 5
    done
   
    echo "Beginning to disassociate and delete public ip: myPIP-$i"
    az network nic update \
        --resource-group $pl_rg_name \
        --name myNic-$i \
        --remove ipConfigurations.[0].publicIpAddress
    echo "myPIP-$i has been disassociated"

    pipAttached=$(az network nic show --resource-group $pl_rg_name --name myNic-$i | jq -r .ipConfigurations[0].publicIpAddress)
    until [ $pipAttached == "null" ];do
        $pipAttached=$(az network nic show --resource-group $pl_rg_name --name myNic-$i | jq -r .ipConfigurations[0].publicIpAddress)
        echo "Pip is still detaching..."
        sleep 5
    done

    az network public-ip delete \
        --resource-group $pl_rg_name \
        --name myPIP-$i
    echo "myPIP-$i has been deleted"

done

# Add IpConfigs to LB Backend pool
echo "Adding VM's to Internal Load Balancer backend pool..."
for i in `seq 3`; do
    ipConfig=$(az network nic ip-config list -g $pl_rg_name --nic-name myNIC-$i | jq -r '.[].name')
    az network nic ip-config address-pool add \
       --address-pool myBackEndPool \
       --ip-config-name $ipConfig \
       --nic-name myNIC-$i \
       --resource-group $pl_rg_name \
       --lb-name myILB
done

echo "App has been deployed behind Private Link Service, deploying Private Endpoint now!"