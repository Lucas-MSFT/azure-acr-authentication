#!/bin/bash

# script name: acr-flp-auth.sh
# Version v0.0.1 20221007
# Set of tools to deploy ACR troubleshooting labs

# "-l|--lab" Lab scenario to deploy
# "-r|--region" region to deploy the resources
# "-u|--user" User alias to add on the lab name
# "-h|--help" help info
# "--version" print version

# read the options
TEMP=`getopt -o g:n:l:r:u:hv --long resource-group:,name:,lab:,region:,user:,help,validate,version -n 'acr-flp-auth.sh' -- "$@"`
eval set -- "$TEMP"

# set an initial value for the flags
RESOURCE_GROUP=""
ACR_NAME=""
LAB_SCENARIO=""
USER_ALIAS=""
LOCATION=""
VALIDATE=0
HELP=0
VERSION=0

while true ;
do
    case "$1" in
        -h|--help) HELP=1; shift;;
        -g|--resource-group) case "$2" in
            "") shift 2;;
            *) RESOURCE_GROUP="$2"; shift 2;;
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
            *) LOCATION="$2"; shift 2;;
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

# Variable definition
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_NAME="$(echo $0 | sed 's|\.\/||g')"
SCRIPT_VERSION="Version v0.0.1 20221007"

# Funtion definition

# az login check
function az_login_check () {
    if $(az account list 2>&1 | grep -q 'az login')
    then
        echo -e "\n--> Warning: You have to login first with the 'az login' command before you can run this lab tool\n"
        az login -o table
    fi
}

# check resource group and acr
function check_resourcegroup_cluster () {
    RESOURCE_GROUP="$1"
    ACR_NAME="$2"

    RG_EXIST=$(az group show -g $RESOURCE_GROUP &>/dev/null; echo $?)
    if [ $RG_EXIST -ne 0 ]
    then
        echo -e "\n--> Creating resource group ${RESOURCE_GROUP}...\n"
        az group create --name $RESOURCE_GROUP --location $LOCATION -o table &>/dev/null
    else
        echo -e "\nResource group $RESOURCE_GROUP already exists...\n"
    fi

    ACR_EXIST=$(az acr show -g $RESOURCE_GROUP -n $ACR_NAME &>/dev/null; echo $?)
    if [ $ACR_EXIST -eq 0 ]
    then
        echo -e "\n--> Azure Container Registry $ACR_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
        exit 5
    fi
}

# validate ACR exists
function validate_acr_exists () {
    RESOURCE_GROUP="$1"
    ACR_NAME="$2"

    ACR_EXIST=$(az acr show -g $RESOURCE_GROUP -n $ACR_NAME &>/dev/null; echo $?)
    if [ $ACR_EXIST -ne 0 ]
    then
        echo -e "\n--> ERROR: Failed to create container registry $ACR_NAME in resource group $RESOURCE_GROUP ...\n"
        exit 5
    fi
}

# Usage text
function print_usage_text () {
    NAME_EXEC="acr-flp-auth"
    echo -e "$NAME_EXEC usage: $NAME_EXEC -l <LAB#> -u <USER_ALIAS> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
    echo -e "\nHere is the list of current labs available:\n
*************************************************************************************
*\t 1. Try to pull an image from the provided ACR until successful.
*\t 2. Pulling ACR image from AKS fails, find the reason and fix it! (use secrets)
*************************************************************************************\n"
}

# Lab scenario 1
function lab_scenario_1 () {
    echo -e "****Creating ACR"
    RESOURCE_GROUP=ACR-Auth-Lab-${USER_ALIAS}-Lab1
    ACR_NAME=acrauthlab$(echo $RANDOM | md5sum | head -c 10; echo;)
    ACRLoginServer="$ACR_NAME"".azurecr.io"
    LOCATION="eastus"
    # Creating ACR RG...
    az group create \
        --location "$LOCATION" \
        --resource-group "$RESOURCE_GROUP"
    # Creating ACR..
    az acr create \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --sku Standard \
        --location "$LOCATION"
    AKSName="ACRLabAKS"
    AKSRGName=ACR-Auth-Lab-AKS-${USER_ALIAS}-Lab1
    # Creating AKS RG...
    az group create \
	 --location "$LOCATION" \
	 --resource-group "$AKSRGName"
    # Pulling Image...
    echo -e "****Pulling NGINX image locally"
    docker pull k8s.gcr.io/e2e-test-images/jessie-dnsutils:1.3
    echo -e "*****Tagging and pushing image to ACR"
    docker tag k8s.gcr.io/e2e-test-images/jessie-dnsutils:1.3 "$ACRLoginServer"/e2e-test-images/jessie-dnsutils:1.3
    az acr login \
        --name "$ACR_NAME"
    docker push "$ACRLoginServer"/e2e-test-images/jessie-dnsutils:1.3
    # Creating AKS Cluster
    echo -e "*****Creating AKS Cluster"
    AKS_SP_DisplayName=aks$(echo $RANDOM | md5sum | head -c 10; echo;)
    scopes="/subscriptions/"$(az account show --query id -o tsv)/resourceGroups/"$AKSRGName"
    # Creating SPN...
    sleep 30
    echo -e "*****Creating Service Principal"
    az ad sp create-for-rbac \
        --role Contributor \
        --scopes "$scopes" \
        -n "$AKS_SP_DisplayName"
    sleep 30
    # Collecting SPN details...
    AKS_APP_ID=$(az ad sp list --display-name $AKS_SP_DisplayName --query "[].appId" -o tsv)
    AKS_SP_ID=$(az ad sp list --display-name $AKS_SP_DisplayName --query "[].id" -o tsv)
    AKS_SP_SECRET=$(az ad sp credential reset --id "$AKS_SP_ID" --query password -o tsv)
    # AKS Creation...
    az aks create \
        --name "$AKSName" \
        --resource-group="$AKSRGName" \
        --location="$LOCATION" \
        --node-count 2 \
        --service-principal "$AKS_APP_ID" \
        --client-secret "$AKS_SP_SECRET"
    echo -e ""
    echo -e ""
    echo -e ""
    echo -e "The AKS cluster has been provisioned. Your details are..."
    echo -e "---"
    echo -e "Resource Group:\t$AKSRGName"
    echo -e "DNS cluster:\t$AKSName"
    echo -e ""
    echo -e "NOTE: This script can not clean up ACR once you are done with them. To delete it, run the following command:"
    echo -e "\t az group delete -n $RESOURCE_GROUP -y --no-wait"
     echo -e "NOTE: This script can not clean up your AKS Cluster once you are done with them. To delete it, run the following command:"
    echo -e "\t az group delete -n $AKSRGName -y --no-wait"
    echo -e "*****Creating Deployment"
    az aks get-credentials --name "$AKSName" --resource-group "$AKSRGName" --overwrite-existing
    # Creating deployment
cat << EOF > Deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: dnsutils
    namespace: default
    labels:
        app: dnsutils
spec:
    replicas: 2
    selector:
        matchLabels:
          app: dnsutils
    template:
        metadata:
          labels:
            app: dnsutils
        spec:
          containers:
          - name: dnsutils
            image: $ACRLoginServer/e2e-test-images/jessie-dnsutils:1.3
            command:
            - sleep
            - "3600"
            imagePullPolicy: Always
EOF

    # Deployment... 
    
    kubectl apply -f ./Deployment.yaml
}

function lab_scenario_1_validation () {
    numberOfReadyReplicas=$(kubectl get deploy dnsutils -o jsonpath='{.status.readyReplicas}') 
    numberOfReplicas=$(kubectl get deploy dnsutils -o jsonpath='{.status.replicas}')
    difference=$((numberOfReplicas-numberOfReadyReplicas))
    exists=$(kubectl get deploy dnsutils -o yaml)
    if [ -z "$exists" ]
    then
        echo "The deployment does not exist"
        exit 5
    fi
    if [ "$difference" -ne 0 ] 
    then 
        echo "The deployment is still not ready" 
        exit 5
    else
	echo "The Deployment is successfully created..."
    fi
}

# Lab scenario 2
function lab_scenario_2 () {
    echo -e "Creating ACR..."
    echo -e "..."
    RESOURCE_GROUP=ACR-Auth-Lab-${USER_ALIAS}-Lab2
    ACR_NAME=acrauthlab${USER_ALIAS}
    ACR_LOGIN_SERVER="$ACR_NAME.azurecr.io"
    LOCATION="eastus"

    az group create --location "$LOCATION" --resource-group "$RESOURCE_GROUP"

    az acr create \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --sku Standard \
        --location "$LOCATION"

    ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query "id" --output tsv)

    echo -e "Importing NGINX image locally..."
    echo -e "..."
    az acr import \
        --name "$ACR_NAME" \
        --source docker.io/library/nginx:latest \
        --image nginx:latest

    echo -e "..."
    AKS_NAME=ACRLabAKS${USER_ALIAS}

    echo -e "Creating AKS Cluster..."
    echo -e "..."
    az aks create \
        --name "$AKS_NAME" \
        --resource-group="$RESOURCE_GROUP" \
        --location="$LOCATION" \
        --node-count 2 \
        --enable-managed-identity \
        --generate-ssh-keys

    FQDN=$(az aks show -n $AKS_NAME -g $RESOURCE_GROUP --query "fqdn" -o tsv)

    echo -e ""
    echo -e ""
    echo -e ""
    echo -e "The AKS cluster has been provisioned. Your details are..."

    echo -e "---"
    echo -e "Resource Group:\t$RESOURCE_GROUP"
    echo -e "Test cluster:\t$FQDN"
    echo -e ""
    echo -e "NOTE: This script can not clean up clusters once you are done with them. To delete them, run the following command:"
    echo -e "\t az group delete -n $RESOURCE_GROUP -y --no-wait"

    echo -e "Creating Pod..."
    az aks get-credentials --name "$AKS_NAME" --resource-group "$RESOURCE_GROUP" -y

cat << EOF > Pod.yaml
apiVersion: v1
kind: Pod

metadata:
  name: my-awesome-app-pod
  namespace: default

spec:
  containers:
    - name: main-app-container
      image: $ACR_NAME.azurecr.io/nginx
      imagePullPolicy: IfNotPresent
  imagePullSecrets:
    - name: auth-secret
EOF

    kubectl apply -f ./Pod.yaml

    validate_acr_exists $RESOURCE_GROUP $ACR_NAME
}

function lab_scenario_2_validation () {
  POD_STATUS="$(kubectl get pod my-awesome-app-pod -o jsonpath='{.status.containerStatuses[0].ready}')"
  if [ $POD_STATUS == 'true' ]
  then
    echo "SUCCESS! The pod now looks good!"
  else
    echo "Scenario FAILED, keep trying!"
  fi
}

#if -h | --help option is selected usage will be displayed
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

# lab scenario has a valid option
if [[ ! $LAB_SCENARIO =~ ^[1-2]+$ ]];
then
    echo -e "\n--> Error: invalid value for lab scenario '-l $LAB_SCENARIO'\nIt must be value from 1 to 2\n"
    exit 11
fi

# main
echo -e "\n--> ACR Troubleshooting sessions
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
