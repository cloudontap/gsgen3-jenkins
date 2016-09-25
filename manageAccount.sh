#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Location of scripts
BIN_DIR="${WORKSPACE}/${AID}/config/bin"

# Create the account level buckets if required
if [[ "${CREATE_ACCOUNT_BUCKETS}" == "true" ]]; then
    cd ${WORKSPACE}/${AID}/config/${AID}
    ${BIN_DIR}/createAccountTemplate.sh -a ${AID}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Generation of the account level template for the ${AID} account failed"
        exit
    fi

    # Create the stack
    ${BIN_DIR}/createStack.sh -t account
	RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Creation of the account level stack for the ${AID} account failed"
        exit
    fi
        
    # Update the infrastructure repo to capture any stack changes
    cd ${WORKSPACE}/${AID}/infrastructure/${AID}

    # Ensure git knows who we are
    git config user.name  "${BUILD_USER}"
    git config user.email "${BUILD_USER_EMAIL}"

    # Record changes
    git add *
    git commit -m "Stack changes as a result of creating the ${AID} account stack"
    git push origin master
	RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Unable to save the changes resulting from creating the ${AID} account stack"
        exit
    fi
fi

# Update the code and credentials buckets if required
if [[ "${SYNC_ACCOUNT_BUCKETS}" == "true" ]]; then
    cd ${WORKSPACE}/${AID}
    ${BIN_DIR}/syncAccountBuckets.sh -a ${AID}
fi

# All good
RESULT=0




