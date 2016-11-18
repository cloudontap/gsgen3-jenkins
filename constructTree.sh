#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi
JENKINS_DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

PRODUCT_CONFIG_REFERENCE_DEFAULT="master"
PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT="master"
GSGEN_BIN_REFERENCE_DEFAULT="master"
GSGEN_STARTUP_REFERENCE_DEFAULT="master"
function usage() {
    echo -e "\nConstruct the account directory tree" 
    echo -e "\nUsage: $(basename $0) -c CONFIG_REFERENCE -i INFRASTRUCTURE_REFERENCE -g GSGEN_BIN_REFERENCE -s GSGEN_STARTUP_REFERENCE -a -p -n"
    echo -e "\nwhere\n"
    echo -e "(o) -a if the account directories should not be included"
    echo -e "(o) -c CONFIG_REFERENCE is the git reference for the config repo"
    echo -e "(o) -g GSGEN_BIN_REFERENCE is the git reference for the GSGEN3 framework bin repo"
    echo -e "    -h shows this text"
    echo -e "(o) -i INFRASTRUCTURE_REFERENCE is the git reference for the config repo"
    echo -e "(o) -n initialise repos if not already initialised"
    echo -e "(o) -p if the product directories should not be included"
    echo -e "(o) -s GSGEN_STARTUP_REFERENCE is the git reference for the GSGEN3 framework startup repo"
    echo -e "\nDEFAULTS:\n"
    echo -e "CONFIG_REFERENCE = ${PRODUCT_CONFIG_REFERENCE_DEFAULT}"
    echo -e "INFRASTRUCTURE_REFERENCE = ${PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT}"
    echo -e "GSGEN_BIN_REFERENCE = ${GSGEN_BIN_REFERENCE_DEFAULT}"
    echo -e "GSGEN_STARTUP_REFERENCE = ${GSGEN_STARTUP_REFERENCE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1. ACCOUNT/PRODUCT details are assumed to be already defined via environment variables"
    echo -e ""
    RESULT=1
    exit
}

# Parse options
while getopts ":ac:g:hi:ps:" opt; do
    case $opt in
        a)
            EXCLUDE_ACCOUNT_DIRECTORIES="true"
            ;;
        c)
            PRODUCT_CONFIG_REFERENCE="${OPTARG}"
            ;;
        g)
            GSGEN_BIN_REFERENCE="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            PRODUCT_INFRASTRUCTURE_REFERENCE="${OPTARG}"
            ;;
        n)
            INIT_REPOS="true"
            ;;
        p)
            EXCLUDE_PRODUCT_DIRECTORIES="true"
            ;;
        g)
            GSGEN_STARTUP_REFERENCE="${OPTARG}"
            ;;
        \?)
            echo -e "\nInvalid option: -$OPTARG" 
            usage
            ;;
        :)
            echo -e "\nOption -$OPTARG requires an argument" 
            usage
            ;;
     esac
done

# Apply defaults
PRODUCT_CONFIG_REFERENCE="${PRODUCT_CONFIG_REFERENCE:-$PRODUCT_CONFIG_REFERENCE_DEFAULT}"
PRODUCT_INFRASTRUCTURE_REFERENCE="${PRODUCT_INFRASTRUCTURE_REFERENCE:-$PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT}"
GSGEN_BIN_REFERENCE="${GSGEN_BIN_REFERENCE:-$GSGEN_BIN_REFERENCE_DEFAULT}"
GSGEN_STARTUP_REFERENCE="${GSGEN_STARTUP_REFERENCE:-$GSGEN_STARTUP_REFERENCE_DEFAULT}"
EXCLUDE_ACCOUNT_DIRECTORIES="${EXCLUDE_ACCOUNT_DIRECTORIES:-false}"
EXCLUDE_PRODUCT_DIRECTORIES="${EXCLUDE_PRODUCT_DIRECTORIES:-false}"

# Check for required context
if [[ -z "${ACCOUNT}" ]]; then
    echo "ACCOUNT not defined"
    usage
fi

# Save for later steps
echo "PRODUCT_CONFIG_REFERENCE=${PRODUCT_CONFIG_REFERENCE}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_INFRASTRUCTURE_REFERENCE=${PRODUCT_INFRASTRUCTURE_REFERENCE}" >> ${WORKSPACE}/context.properties

# Define the top level directory representing the account
ROOT_DIR="${WORKSPACE}/${ACCOUNT}"

if [[ !("${EXCLUDE_PRODUCT_DIRECTORIES}" == "true") ]]; then
    
    # Pull in the product config repo
    PRODUCT_URL="https://${!PRODUCT_GIT_CREDENTIALS_VAR}@${PRODUCT_GIT_DNS}/${PRODUCT_GIT_ORG}/${PRODUCT_CONFIG_REPO}"
    PRODUCT_DIR="${ROOT_DIR}/config/${PRODUCT}"
    ${JENKINS_DIR}/manageRepo.sh -c -n "product config" -u "${PRODUCT_URL}" \
        -d "${PRODUCT_DIR}" -b "${PRODUCT_CONFIG_REFERENCE}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
 	    exit
    fi
    
    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${JENKINS_DIR}/manageRepo.sh -i -n "product config" -u "${PRODUCT_URL}" \
            -d "${PRODUCT_DIR}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi

    echo "PRODUCT_CONFIG_COMMIT=$(git -C ${PRODUCT_DIR} rev-parse HEAD)" >> ${WORKSPACE}/context.properties
fi

if [[ !("${EXCLUDE_ACCOUNT_DIRECTORIES}" == "true") ]]; then

    # Pull in the account config repo
    ACCOUNT_URL="https://${!ACCOUNT_GIT_CREDENTIALS_VAR}@${ACCOUNT_GIT_DNS}/${ACCOUNT_GIT_ORG}/${ACCOUNT_CONFIG_REPO}"
    ACCOUNT_DIR="${ROOT_DIR}/config/${ACCOUNT}"
    ${JENKINS_DIR}/manageRepo.sh -c -n "account config" -u "${ACCOUNT_URL}" \
        -d "${ACCOUNT_DIR}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        exit
    fi

    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${JENKINS_DIR}/manageRepo.sh -i -n "account config" -u "${ACCOUNT_URL}" \
            -d "${ACCOUNT_DIR}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi
fi

# Pull in the default GSGEN repo if not overridden by product
GSGEN_DIR="${ROOT_DIR}/config/bin"
if [[ -d ${ROOT_DIR}/config/${PRODUCT}/bin ]]; then
    mkdir -p "${GSGEN_DIR}"
    cp -rp ${ROOT_DIR}/config/${PRODUCT}/bin "${GSGEN_DIR}"
else
    GSGEN_URL="https://${GSGEN_GIT_DNS}/${GSGEN_GIT_ORG}/${GSGEN_BIN_REPO}"
    ${JENKINS_DIR}/manageRepo.sh -c -n "gsgen bin" -u "${GSGEN_URL}" \
        -d "${GSGEN_DIR}" -b "${GSGEN_BIN_REFERENCE}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        exit
    fi
fi

if [[ !("${EXCLUDE_PRODUCT_DIRECTORIES}" == "true") ]]; then
    
    # Pull in the product infrastructure repo
    PRODUCT_URL="https://${!PRODUCT_GIT_CREDENTIALS_VAR}@${PRODUCT_GIT_DNS}/${PRODUCT_GIT_ORG}/${PRODUCT_INFRASTRUCTURE_REPO}"
    PRODUCT_DIR="${ROOT_DIR}/infrastructure/${PRODUCT}"
    ${JENKINS_DIR}/manageRepo.sh -c -n "product infrastructure" -u "${PRODUCT_URL}" \
        -d "${PRODUCT_DIR}" -b "${PRODUCT_INFRASTRUCTURE_REFERENCE}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
 	    exit
    fi
    
    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${JENKINS_DIR}/manageRepo.sh -i -n "product infrastructure" -u "${PRODUCT_URL}" \
            -d "${PRODUCT_DIR}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi

    echo "PRODUCT_INFRASTRUCTURE_COMMIT=$(git -C ${PRODUCT_DIR} rev-parse HEAD)" >> ${WORKSPACE}/context.properties
fi

if [[ !("${EXCLUDE_ACCOUNT_DIRECTORIES}" == "true") ]]; then

    # Pull in the account infrastructure repo
    ACCOUNT_URL="https://${!ACCOUNT_GIT_CREDENTIALS_VAR}@${ACCOUNT_GIT_DNS}/${ACCOUNT_GIT_ORG}/${ACCOUNT_INFRASTRUCTURE_REPO}"
    ACCOUNT_DIR="${ROOT_DIR}/infrastructure/${ACCOUNT}"
    ${JENKINS_DIR}/manageRepo.sh -c -n "account infrastructure" -u "${ACCOUNT_URL}" \
        -d "${ACCOUNT_DIR}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        exit
    fi

    # Initialise if necessary
    if [[ "${INIT_REPOS}" == "true" ]]; then
        ${JENKINS_DIR}/manageRepo.sh -i -n "account infrastructure" -u "${ACCOUNT_URL}" \
            -d "${ACCOUNT_DIR}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            exit
        fi
    fi
fi

# Pull in the default GSGEN startup repo if not overridden by product
GSGEN_DIR="${ROOT_DIR}/infrastructure/startup"
if [[ -d ${ROOT_DIR}/infrastructure/${PRODUCT}/startup ]]; then
    mkdir -p "${GSGEN_DIR}"
    cp -rp ${ROOT_DIR}/infrastructure/${PRODUCT}/startup "${GSGEN_DIR}"
else
    GSGEN_URL="https://${GSGEN_GIT_DNS}/${GSGEN_GIT_ORG}/${GSGEN_STARTUP_REPO}"
    ${JENKINS_DIR}/manageRepo.sh -c -n "gsgen startup" -u "${GSGEN_URL}" \
        -d "${GSGEN_DIR}" -b "${GSGEN_STARTUP_REFERENCE}"
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        exit
    fi
fi

# All good
RESULT=0

