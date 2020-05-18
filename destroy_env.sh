##############################################################################################################
##############################################################################################################
#
#   Tear Down Private Link Resource Group
#
##############################################################################################################
##############################################################################################################

# Importing Variables
set -a 
. ./config.sh
set +a

# Destroy the PE RG's
echo "Destroying Private Endpoint Resource Group(s).."
for i in `seq $num_of_pe`; do 
    az group delete --name $pe_rg_prefix-$i --yes
    echo "Resrouce Group $pe_rg_prefix-$i has been deleted"
done

# Destroy the PLS RG
echo "Destroying Private Link Resource Group.."
az group delete --name $pl_rg_name --yes
echo "Resrouce Group $pl_rg_name has been deleted"

echo "All resources have been destroyed"