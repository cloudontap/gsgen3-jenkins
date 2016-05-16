#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set -x; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

# Location of scripts
BIN_DIR="${WORKSPACE}/${OAID}/config/bin"

# Create the account level buckets if required
if [[ "${CREATE_ACCOUNT_BUCKETS}" == "true" ]]; then
    cd ${WORKSPACE}/${OAID}/config/${OAID}
    ${BIN_DIR}/createAccountTemplate.sh -a ${OAID}
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Generation of the account level template for the ${OAID} account failed"
        exit
    fi

    # Create the stack
    ${BIN_DIR}/createStack.sh -t account
	RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Creation of the account level stack for the ${OAID} account failed"
        exit
    fi
        
    # Update the infrastructure repo to capture any stack changes
    cd ${WORKSPACE}/${OAID}/infrastructure/${OAID}

    # Ensure git knows who we are
    git config user.name  "${BUILD_USER}"
    git config user.email "${BUILD_USER_EMAIL}"

    # Record changes
    git add *
    git commit -m "Stack changes as a result of applying ${MODE} mode to the ${LEVEL} level stack for the ${SLICE} slice of the ${ENVIRONMENT} environment"
    git push origin master
	RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Unable to save the changes resulting from applying ${MODE} mode to the ${LEVEL} level stack for the ${SLICE} slice of the ${ENVIRONMENT} environment"
        exit
    fi
fi

# Update the code and credentials buckets if required
if [[ "${SYNC_ACCOUNT_BUCKETS}" == "true" ]]; then
    cd ${WORKSPACE}/${OAID}
    echo $AWS_ACCESS_KEY_ID
    echo $AWS_SECRET_ACCESS_KEY
    ${BIN_DIR}/syncAccountBuckets.sh -a ${OAID}
fi



