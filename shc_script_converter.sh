#!/bin/bash

## Script to convert the base lab scripts to binaries

SHC_STATUS=$(which shc > /dev/null; echo $?)
if [ $SHC_STATUS -ne 0 ]
then
    echo -e "\nError: missing shc binary...\n"
    exit 4
fi

ACRLABS_SCRIPTS="$(ls ./acrlabs_scripts/)"
if [ -z "$ACRLABS_SCRIPTS" ]
then
    echo -e "Error: missing acrlabs scripts...\n"
    exit 5
fi

function convert_to_binary() {
    SCRIPT_NAME="$1"
    BINARY_NAME="$(echo "$SCRIPT_NAME" | sed 's/.sh//')"
    shc -f ./acrlabs_scripts/${SCRIPT_NAME} -r -o ./acrlabs_binaries/${BINARY_NAME}
    rm -f ./acrlabs_scripts/${SCRIPT_NAME}.x.c > /dev/null 2>&1
}

for FILE in $(echo "$ACRLABS_SCRIPTS")
do
    convert_to_binary $FILE
done

exit 0
