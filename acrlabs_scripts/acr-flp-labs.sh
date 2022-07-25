#!/bin/bash

## script name: acr-flp-labs.sh
## Version v0.0.1 20220725
## Set of tools to deploy ACI troubleshooting labs

## "-l|--lab" Lab scenario to deploy
## "-r|--region" region to deploy the resources
## "-u|--user" User alias to add on the lab name
## "-h|--help" help info
## "--version" print version

## read the options
TEMP=`getopt -o g:n:l:r:u:hv --long resource-group:,name:,lab:,region:,user:,help,validate,version -n 'aci-flp-labs.sh' -- "$@"`
eval set -- "$TEMP"

## set an initial value for the flags
RESOURCE_GROUP=""
ACR_NAME=""
LAB_SCENARIO=""
USER_ALIAS=""
LOCATION="westeurope"
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

    ACI_EXIST=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME &>/dev/null; echo $?)
    if [ $ACI_EXIST -eq 0 ]
    then
        echo -e "\n--> Container Registry $ACR_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
        exit 5
    fi
}

## Validate ACR exists
function validate_acr_exists () {
    RESOURCE_GROUP="$1"
    ACI_NAME="$2"

    ACI_EXIST=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME &>/dev/null; echo $?)
    if [ $ACI_EXIST -ne 0 ]
    then
        echo -e "\n--> ERROR: Failed to create container instance $ACI_NAME in resource group $RESOURCE_GROUP ...\n"
        exit 5
    fi
}

# Usage text
function print_usage_text () {
    NAME_EXEC="aci-flp-labs"
    echo -e "$NAME_EXEC usage: $NAME_EXEC -l <LAB#> -u <USER_ALIAS> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
    echo -e "\nHere is the list of current labs available:\n
*************************************************************************************
CORE LABS:
*\t 1. ACI deployment failure configuration
*\t 2. ACI deployment authorization failed
*\t 3. ACI connection issue between 2 container groups V1
*\t 4. ACI deployment failed netwwork configuration V1
*\t 5. ACI deployment failed with Log analytics
*\t 6. ACI container create failure with Azure File mount
*\t 7. ACI deployment failure with Storage account
*\t 8. ACI container create image pull failure V1


EXTRA LABS:
*\t 9. ACI deployment failure on pre-existing vnet
*\t 10. ACI container continuous restart issue
*\t 11. ACI container create image pull failure V2
*\t 12. ACI deployment failed netwwork configuration V2 
*\t 13. ACI connection issue between 2 container groups V2
*\t 14. ACI connection issue to container
*************************************************************************************\n"
}





# Lab scenario 1
function lab_scenario_1 () {

    ACI_NAME="appcontaineryaml"
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}
    ACI_LENGTH_STRING=12
    ACI_CONTAINER_DNS_LABEL=$(tr -dc a-z </dev/urandom | head -c $ACI_LENGTH_STRING)
    ACI_CONTAINER_IMAGE="mcr.microsoft.com/azuredocs/aci-helloworld"

    echo -e "\n--> Deploying resources for lab${LAB_SCENARIO}...\n"
    
    ## Remove any previous aci.yaml file
    rm -rf aci.yaml

cat <<EOF > aci.yaml
apiVersion: '2021-07-01'
location: $LOCATION
name: $ACI_NAME
properties:
  containers:
  - name: $ACI_NAME
    properties:
      image: mcr.microsoft.com/azuredocs/aci-helloworld
      ports:
      - port: 80
        protocol: TCP
      resources:
        requests:
          cpu: 1.0
          memoryInGB: 1.5
  ipAddress:
    type: Public
    ports:
    - protocol: tcp
      port: '80'
  osType: Linux
  restartPolicy: Always
tags: null
type: Microsoft.ContainerInstance/containerGroups
EOF

    ERROR_MESSAGE="$(az container create --resource-group $RESOURCE_GROUP --file aci.yaml 2>&1)"

    echo -e "\n\n********************************************************"
    echo -e "\n--> Issue description: \n Customer wants to deploy an ACI using the following:"
    echo -e "az container create --resource-group $RESOURCE_GROUP --file aci.yaml\n"
    echo -e "Cx is getting the error message:"
    echo -e "\n-------------------------------------------------------------------------------------\n"
    echo $ERROR_MESSAGE
    echo -e "\n-------------------------------------------------------------------------------------\n"
    echo -e "The yaml file aci.yaml is in your current path, you have to modified it in order to be able to deploo
y the second container instance \"appcontaineryaml\"\n"
    echo -e "Once you find the issue, update the aci.yaml file and run the commnad:"
    echo -e "az container create --resource-group $RESOURCE_GROUP --file aci.yaml\n"
}


function lab_scenario_1_validation () {

    ACI_NAME="appcontaineryaml"
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}

    validate_aci_exists $RESOURCE_GROUP $ACI_NAME

    ACI_STATUS=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME &>/dev/null; echo $?)

    if [ $ACI_STATUS -eq 0 ]
    then
        echo -e "\n\n========================================================"
        echo -e '\nContainer instance "appcontaineryaml" looks good now!\n'
    else
        echo -e "\n--> Error: Scenario $LAB_SCENARIO is still FAILED\n\n"
        echo -e "The yaml file aci.yaml is in your current path, you have to modified it in order to be able to dd
eploy the second container instance \"appcontaineryaml\"\n"
        echo -e "Once you find the issue, update the aci.yaml file and run the commnad:"
        echo -e "az container create --resource-group $RESOURCE_GROUP --file aci.yaml\n"
    fi

}



# Lab scenario 2
function lab_scenario_2 () {
  ACI_SP_NAME="sp-aci-lab2"
  ACI_NAME="mycontainer"
  RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}

  check_resourcegroup_cluster $RESOURCE_GROUP $ACI_NAME

  echo -e "\n--> Deploying resources for lab${LAB_SCENARIO}...\n"

  ACI_RG_URI=$(az group list \
   --output json | jq -r ".[] | select ( .name == \"$RESOURCE_GROUP\") | [ .id] | @tsv")


  declare -a ARR_SP_DETAILS

  ARR_SP_DETAILS=($(az ad sp create-for-rbac \
  --name $ACI_SP_NAME \
  --role Reader \
  --scopes $ACI_RG_URI 2>/dev/null | jq -r ". | [ .password, .appId , .displayName ] | @tsv"))

  TENANT=$(az account list \
    --output json | jq -r ".[] | select ( .isDefault == "true" ) | [ .tenantId] | @tsv")

  #AZ_LOGIN_STRING=$(echo "az login --service-principal --username ${ARR_SP_DETAILS[1]} --password ${ARR_SP_DETAILS[0]} --tenant $TENANT") 
  #"Login With Another SP"
  #bash $AZ_LOGIN_STRING &>/dev/null

  #echo "Waiting... 60s"
  sleep 60
  
  # Do the SP Login
  az login --service-principal --username ${ARR_SP_DETAILS[1]} --password ${ARR_SP_DETAILS[0]} --tenant $TENANT  &>/dev/null

  ## Create Container
  ERROR_MESSAGE="$(az container create \
    --resource-group $RESOURCE_GROUP \
    --name $ACI_NAME \
    --image mcr.microsoft.com/azure-cli \
    --command-line "sleep infinity" 2>&1)"  

  echo -e "\n\n************************************************************************\n"
  echo -e "\n--> Issue description: \n Customer needs to deploy an ACI in the resource group $RESOURCE_GROUP"
  echo -e "az container create --resource-group $RESOURCE_GROUP --name $ACI_NAME --image mcr.microsoft.com/azure-cli --command-line \"tail -f /dev/null\"\n"
  echo -e "Cx is getting the error message:"
  echo -e "\n-------------------------------------------------------------------------------------\n"
  echo -e "$ERROR_MESSAGE"
  echo -e "\n-------------------------------------------------------------------------------------\n"
  echo -e "Once you find the issue, run again the previous command to deploy ACI"

}


function lab_scenario_2_validation () {
  ACI_SP_NAME="sp-aci-lab2"
  ACI_NAME="mycontainer"
  RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}

  ## Test se ACI corre com SP criado
  ACI_STATUS=$(az container list \
    --output json  | jq -r ".[] | select ( .name == \"$ACI_NAME\" ) | select ( .resourceGroup == \"$RESOURCE_GROUP\") | [ .id] | @tsv" | wc -l) 


  if [[ "$ACI_STATUS" == "1" ]]
  then
        echo -e "\n\n========================================================"
        echo -e "\nContainer instance $ACI_NAME looks good now!\n"
  else
        echo -e "\n--> Error: Scenario $LAB_SCENARIO is still FAILED\n\n"
        echo -e "Once you find the issue, run agains the $LAB_SCENARIO"
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

REG_EX="^\\b([1-9]|1[0-4])\\b"

if [[ ! $LAB_SCENARIO =~ $REG_EX ]];
then
    echo -e "\n--> Error: invalid value for lab scenario '-l $LAB_SCENARIO'\nIt must be value from 1 to 14\n"
    exit 11
fi

# main
echo -e "\n--> ACI Troubleshooting sessions
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
elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_3
elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_3_validation
elif [ $LAB_SCENARIO -eq 4 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_4
elif [ $LAB_SCENARIO -eq 4 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_4_validation
elif [ $LAB_SCENARIO -eq 5 ] && [ $VALIDATE -eq 0 ] 
then
    check_resourcegroup_cluster
    lab_scenario_5
elif [ $LAB_SCENARIO -eq 5 ] && [ $VALIDATE -eq 1 ] 
then
    lab_scenario_5_validation
elif [ $LAB_SCENARIO -eq 6 ] && [ $VALIDATE -eq 0 ] 
then
    check_resourcegroup_cluster
    lab_scenario_6
elif [ $LAB_SCENARIO -eq 6 ] && [ $VALIDATE -eq 1 ] 
then
    lab_scenario_6_validation
elif [ $LAB_SCENARIO -eq 7 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_7
elif [ $LAB_SCENARIO -eq 7 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_7_validation
elif [ $LAB_SCENARIO -eq 8 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_8
elif [ $LAB_SCENARIO -eq 8 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_8_validation
elif [ $LAB_SCENARIO -eq 9 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_9
elif [ $LAB_SCENARIO -eq 9 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_9_validation
elif [ $LAB_SCENARIO -eq 10 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_10
elif [ $LAB_SCENARIO -eq 10 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_7_validation
elif [ $LAB_SCENARIO -eq 11 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_11
elif [ $LAB_SCENARIO -eq 11 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_11_validation
elif [ $LAB_SCENARIO -eq 12 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_12
elif [ $LAB_SCENARIO -eq 12 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_12_validation
elif [ $LAB_SCENARIO -eq 13 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_13
elif [ $LAB_SCENARIO -eq 13 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_13_validation
elif [ $LAB_SCENARIO -eq 14 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_14
elif [ $LAB_SCENARIO -eq 14 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_14_validation
else
    echo -e "\n--> Error: no valid option provided\n"
    exit 12
fi

exit 0
