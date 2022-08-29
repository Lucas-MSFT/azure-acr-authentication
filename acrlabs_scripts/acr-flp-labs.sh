#!/bin/bash

## script name: acr-flp-labs.sh
## Set of tools to deploy ACR Troubleshooting Labs

## "-l|--lab" Lab scenario to deploy
## "-r|--region" region to deploy the resources
## "-u|--user" User alias to add on the lab name
## "-h|--help" help info
## "--version" print version

## read the options
TEMP=`getopt -o g:n:l:r:u:hv --long resource-group:,name:,lab:,region:,user:,help,validate,version -n 'acr-flp-labs.sh' -- "$@"`
eval set -- "$TEMP"

## set an initial value for the flags
ACR_RG_NAME=""
ACR_NAME=""
LAB_SCENARIO=""
USER_ALIAS=""
ACR_RG_LOCATION="westeurope"
VALIDATE=0
HELP=0
VERSION=0

while true ;
do
    case "$1" in
        -h|--help) HELP=1; shift;;
        -g|--resource-group) case "$2" in
            "") shift 2;;
            *) ACR_RG_NAME="$2"; shift 2;;
            esac;;
        -n|--name) case "$2" in
            "") shift 2;;
            *) ACR_NAME="$2"; shift 2;;
            esac;;
        -l|--lab) case "$2" in
            "") shift 2;;
            *) LAB_SCENARIO="$2"; shift 2;;
            esac;;
        -r|--region) case "$2" in
            "") shift 2;;
            *) ACR_RG_LOCATION="$2"; shift 2;;
            esac;;
        -u|--user) case "$2" in
            "") shift 2;;
            *) USER_ALIAS="$2"; shift 2;;
            esac;;    
        -v|--validate) VALIDATE=1; shift;;
        --version) VERSION=1; shift;;
        --) shift ; break ;;
        *) echo -e "Error: invalid argument\n" ; exit 3 ;;
    esac
done

## Variable definition
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_NAME="$(echo $0 | sed 's|\.\/||g')"
SCRIPT_VERSION="Version v0.0.1 20220725"

########################
## Funtion definition ##
########################

## az login check
function az_login_check () {
    if $(az account list 2>&1 | grep -q 'az login')
    then
        echo -e "\n--> Warning: You have to login first with the 'az login' command before you can run this lab tool\n"
        az login -o table
    fi
}

## Check Resource Group and ACR
function check_resourcegroup_cluster () {
    RG_EXIST=$(az group show -g $ACR_RG_NAME &>/dev/null; echo $?)
    if [ $RG_EXIST -ne 0 ]
    then
        echo -e "\n--> Creating resource group ${ACR_RG_NAME}...\n"
        az group create --name $ACR_RG_NAME --location $ACR_RG_LOCATION -o table &>/dev/null
    else
        echo -e "\nResource group $ACR_RG_NAME already exists...\n"
    fi

    ACR_EXIST=$(az acr show -g $ACR_RG_NAME -n $ACR_NAME &>/dev/null; echo $?)
    if [ $ACR_EXIST -eq 0 ]
    then
        echo -e "\n--> Container Registry $ACR_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
        exit 5
    fi
}

## Usage text
function print_usage_text () {
    NAME_EXEC="acr-flp-labs"
    echo -e "$NAME_EXEC usage: $NAME_EXEC -l <LAB#> -u <USER_ALIAS> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
    echo -e "\nHere is the list of current labs available:\n
*************************************************************************************
CORE LABS:
*\t 1. ACR Network - Private Endpoint
*\t 2. ACR Network - Firewall

*************************************************************************************\n"
}



## Lab scenario 1
## ACR Network - Private Endpoint
function lab_scenario_1 () {

## Set defaults
ACR_VNET_NAME=acrlab1vnet
ACR_SUBNET_NAME=default
ACR_SKU="Premium"

AKS_NAME="acr-lab1-aks"
AKS_NODE_COUNT="1"
AKS_NETWORK_PLUGIN="azure"

AKS_VNET_CIDR="10.0.0.0/16"
AKS_SNET_NAME="default"
AKS_SNET_CIDR="10.0.1.0/24"


## Create ACR
#echo "Create ACR"
az acr create \
  --resource-group $ACR_RG_NAME \
  --name $ACR_NAME \
  --sku $ACR_SKU &>/dev/null

## To create AKS we need to have the priv/puv keys or generate keys 
#echo "Generate priv pub keys"
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N '' <<< y >/dev/null 2>&1


## Create AKS cluster with 1 node and attach to ACR
#echo "Create AKS cluster with 1 node and attach to ACR"
az aks create \
  --resource-group $ACR_RG_NAME \
  --name $AKS_NAME \
  --attach-acr $ACR_NAME \
  --node-count $AKS_NODE_COUNT \
  --network-plugin $AKS_NETWORK_PLUGIN &>/dev/null 

## Create a second empty decoy VNET and create a pvt endpoint to this VNET on the ACR
#echo "Create a second empty decoy VNET and create a pvt endpoint to this VNET on the ACR"
az network vnet create \
  --resource-group $ACR_RG_NAME \
  --name $ACR_VNET_NAME \
  --address-prefixes $AKS_VNET_CIDR \
  --subnet-name $AKS_SNET_NAME \
  --subnet-prefixes $AKS_SNET_CIDR &>/dev/null

## Create Vnet for ACR
#echo "Create Vnet for ACR"
az network vnet subnet update \
  --name $ACR_SUBNET_NAME \
  --vnet-name $ACR_VNET_NAME \
  --resource-group $ACR_RG_NAME \
  --disable-private-endpoint-network-policies &>/dev/null

## Create Private DNS Zone
#echo "Create Private DNS Zone"
az network private-dns zone create \
  --resource-group $ACR_RG_NAME \
  --name "privatelink.azurecr.io" &>/dev/null

## Create Private DNS Link Vnet
#echo "Create Private DNS Link Vnet"
az network private-dns link vnet create \
  --resource-group $ACR_RG_NAME \
  --zone-name "privatelink.azurecr.io" \
  --name MyDNSLink \
  --virtual-network $ACR_VNET_NAME \
  --registration-enabled false &>/dev/null

## Get Registry ID
#echo "Get Registry ID"
REGISTRY_ID=$(az acr show \
    --name $ACR_NAME \
    --query 'id' \
    --output tsv)

## Create Private Endpoint
#echo "Create Private Endpoint"
az network private-endpoint create \
  --name myPrivateEndpoint \
  --resource-group $ACR_RG_NAME \
  --vnet-name $ACR_VNET_NAME \
  --subnet $ACR_SUBNET_NAME \
  --private-connection-resource-id $REGISTRY_ID \
  --group-id registry \
  --connection-name myConnection &>/dev/null

## Get Network Interface ID
#echo "Get Network Interface ID"
NETWORK_INTERFACE_ID=$(az network private-endpoint show \
  --name myPrivateEndpoint \
  --resource-group $ACR_RG_NAME \
  --query 'networkInterfaces[0].id' \
  --output tsv)

## Get Registry Private IP
#echo "Get Registry Private IP"
REGISTRY_PRIVATE_IP=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateIpAddress" \
  --output tsv)

## Get Data EndPoint Private IP
#echo "Get Data EndPoint Private IP"
DATA_ENDPOINT_PRIVATE_IP=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_eastus'].privateIpAddress" \
  --output tsv)

## An FQDN is associated with each IP address in the IP configurations
#echo "Get Registry FQDN"
REGISTRY_FQDN=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateLinkConnectionProperties.fqdns" \
  --output tsv)

## Get Data Endpoint FQDN
#echo "Get Data Endpoint FQDN"
DATA_ENDPOINT_FQDN=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_eastus'].privateLinkConnectionProperties.fqdns" \
  --output tsv)

## Set Private DNS Record 
#echo "Set Private DNS Record"
az network private-dns record-set a create \
  --name $ACR_NAME \
  --zone-name privatelink.azurecr.io \
  --resource-group $ACR_RG_NAME &>/dev/null

## Specify registry region in data endpoint name
#echo "Specify registry region in data endpoint name"
az network private-dns record-set a create \
  --name ${ACR_NAME}.${ACR_RG_LOCATION}.data \
  --zone-name privatelink.azurecr.io \
  --resource-group $ACR_RG_NAME &>/dev/null

## Create A Record in Private DNS Record Set
#echo "Create A Record in Private DNS Record Set"
az network private-dns record-set a add-record \
  --record-set-name $ACR_NAME \
  --zone-name privatelink.azurecr.io \
  --resource-group $ACR_RG_NAME \
  --ipv4-address $REGISTRY_PRIVATE_IP &>/dev/null


## Specify registry region in data endpoint name
#echo "Specify registry region in data endpoint name"
az network private-dns record-set a add-record \
  --record-set-name ${ACR_NAME}.${ACR_RG_LOCATION}.data \
  --zone-name privatelink.azurecr.io \
  --resource-group $ACR_RG_NAME \
  --ipv4-address $DATA_ENDPOINT_PRIVATE_IP &>/dev/null

## Import HelloWorld image to ACR
#echo "Import HelloWorld image to ACR"
az acr import \
  --name $ACR_NAME \
  --source mcr.microsoft.com/azuredocs/aks-helloworld:v1 \
  --image aks-helloworld:v1 &>/dev/null

## Disable public access on the ACR
#echo "Disable public access on the ACR"
az acr update \
  --name $ACR_NAME \
  --public-network-enabled false &>/dev/null


## Deploy an app to AKS that needs to pull the imported helloworld image, pulling the image will fail
#echo "Deploy an app to AKS that needs to pull the imported helloworld image, pulling the image will fail"
az aks get-credentials \
  --resource-group $ACR_RG_NAME \
  --name $AKS_NAME \
  --overwrite-existing

## Create AKS NS for the Workload
#echo "Create AKS NS for the Workload"
kubectl create ns workload &>/dev/null


## Deploy the workload
#echo "Deploy the workload"
cat <<EOF | kubectl -n workload apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aks-helloworld-one  
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aks-helloworld-one
  template:
    metadata:
      labels:
        app: aks-helloworld-one
    spec:
      containers:
      - name: aks-helloworld-one
        image: $ACR_NAME.azurecr.io/aks-helloworld:v1
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        env:
        - name: TITLE
          value: "Welcome to Azure Kubernetes Service (AKS)"
EOF


POD_STATUS=$(kubectl -n workload get po -l app=aks-helloworld-one -o json | jq -r ".items[].status.containerStatuses[].state.waiting.reason")

while [ "$POD_STATUS" != "ErrImagePull" ]
do
  ## Delete Pod to force the issue
  #echo "Delete Pod to force the issue"
  kubectl --namespace workload delete po -l app=aks-helloworld-one &>/dev/null
  sleep 10
  POD_STATUS=$(kubectl -n workload get po -l app=aks-helloworld-one -o json | jq -r ".items[].status.containerStatuses[].state.waiting.reason")
  #echo ""
  #echo "Current Pod Status: $POD_STATUS"
done


echo "END"
}


function lab_scenario_1_validation () {
    POD_STATUS=$(kubectl -n workload get po -l app=aks-helloworld-one -o json | jq -r ".items[].status.containerStatuses[].state.running.startedAt")

    if [[ "$POD_STATUS" != "null" ]]
    then
        echo -e "\n\n========================================================"
        echo -e "\nPod is running!\n"
    else
        echo -e "\n--> Error: Scenario $LAB_SCENARIO is still FAILED\n\n"
        echo -e "Pod is not Running!\n"
    fi
}



## Lab scenario 2
## ACR Network - Firewall
function lab_scenario_2 () {

ACR_SKU="Premium"

AKS_RG_NAME=$ACR_RG_NAME
AKS_NAME="aks-acr-net-lab02"
AKS_NODES_COUNT="1"
AKS_NETWORK_PLUGIN="azure"


## Create ACR
#echo "Create ACR"
az acr create \
  --resource-group $ACR_RG_NAME \
  --name $ACR_NAME \
  --sku $ACR_SKU &>/dev/null


## Import HelloWorld image to ACR
#echo "Import HelloWorld image to ACR"
az acr import \
  --name $ACR_NAME \
  --source mcr.microsoft.com/azuredocs/aks-helloworld:v1 \
  --image aks-helloworld:v1 &>/dev/null


## Set ACR to default Deny to limit access to select networks, with no rules
#echo "Set ACR to default Deny to limit access to select networks, with no rules"
az acr update \
  --name $ACR_NAME \
  --default-action Deny &>/dev/null

## To create AKS we need to have the priv/puv keys or generate keys 
#echo "Generate priv pub keys"
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N '' <<< y >/dev/null 2>&1


## Create AKS cluster with 1 node and attach to ACR
#echo "Create AKS cluster with 1 node and attach to ACR"
az aks create \
  --resource-group $ACR_RG_NAME \
  --name $AKS_NAME \
  --attach-acr $ACR_NAME \
  --node-count $AKS_NODES_COUNT \
  --network-plugin $AKS_NETWORK_PLUGIN &>/dev/null


## Deploy an app to AKS that needs to pull the imported helloworld image, pulling the image will fail
#echo "Deploy an app to AKS that needs to pull the imported helloworld image, pulling the image will fail"
az aks get-credentials \
  --resource-group $ACR_RG_NAME \
  --name $AKS_NAME \
  --overwrite-existing &>/dev/null


## Create workload NS
#echo "Create workload NS"
kubectl create ns workload

## Execute deployment
cat <<EOF | kubectl -n workload apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aks-helloworld-one  
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aks-helloworld-one
  template:
    metadata:
      labels:
        app: aks-helloworld-one
    spec:
      containers:
      - name: aks-helloworld-one
        image: $ACR_NAME.azurecr.io/aks-helloworld:v1
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        env:
        - name: TITLE
          value: "Welcome to Azure Kubernetes Service (AKS)"
EOF

}

function lab_scenario_2_validation () {
    POD_STATUS=$(kubectl -n workload get po -l app=aks-helloworld-one -o json | jq -r ".items[].status.containerStatuses[].state.running.startedAt")

    if [[ "$POD_STATUS" != "null" ]]
    then
        echo -e "\n\n========================================================"
        echo -e "\nPod is running!\n"
    else
        echo -e "\n--> Error: Scenario $LAB_SCENARIO is still FAILED\n\n"
        echo -e "Pod is not Running!\n"
    fi  
}

## If -h | --help option is selected usage will be displayed
if [ $HELP -eq 1 ]
then
	print_usage_text
    echo -e '"-l|--lab" Lab scenario to deploy (3 possible options)
"-r|--region" region to create the resources
"--version" print version of aci-flp-labs
"-h|--help" help info\n'
	exit 0
fi

if [ $VERSION -eq 1 ]
then
	echo -e "$SCRIPT_VERSION\n"
	exit 0
fi

if [ -z $LAB_SCENARIO ]; then
	echo -e "\n--> Error: Lab scenario value must be provided. \n"
	print_usage_text
	exit 9
fi

if [ -z $USER_ALIAS ]; then
	echo -e "Error: User alias value must be provided. \n"
	print_usage_text
	exit 10
fi

if [[ "$ACR_RG_NAME" == "" ]]
then
  ACR_RG_NAME="rg-acr-flp-labs"
fi

if [[ "$ACR_NAME" == "" ]]
then
  ACR_NAME=$(shuf -er -n10 {a..z} {0..9} | paste -sd "")
  #echo "Since ACR_NAME is Empty..."
  #echo "Final Name for ACR: $ACR_NAME"
fi


## lab scenario has a valid option
REG_EX="^\\b([1-2]|)\\b"

if [[ ! $LAB_SCENARIO =~ $REG_EX ]];
then
    echo -e "\n--> Error: invalid value for lab scenario '-l $LAB_SCENARIO'\nIt must be value from 1 to 2\n"
    exit 11
fi


##########
## main ##
##########

echo -e "\n--> ACR Troubleshooting Sessions
********************************************

This tool will use your default subscription to deploy the lab environments.
Verifing if you are authenticated already...\n"

# Verify az cli has been authenticated
az_login_check

if [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_1
elif [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_1_validation
elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_2
elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_2_validation
else
    echo -e "\n--> Error: no valid option provided\n"
    exit 12
fi

exit 0
