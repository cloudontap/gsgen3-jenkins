#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

PRODUCT_CONFIG_REFERENCE_DEFAULT="master"
PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT="master"
GSGEN_BIN_REFERENCE_DEFAULT="master"
GSGEN_STARTUP_REFERENCE_DEFAULT="master"
function usage() {
    echo -e "\nConstruct the account directory tree" 
    echo -e "\nUsage: $(basename $0) -c CONFIG_REFERENCE -i INFRASTRUCTURE_REFERENCE -g GSGEN_BIN_REFERENCE -s GSGEN_STARTUP_REFERENCE -a -p"
    echo -e "\nwhere\n"
    echo -e "(o) -a if the account directories should not be included"
    echo -e "(o) -c CONFIG_REFERENCE is the git reference for the config repo"
    echo -e "(o) -g GSGEN_BIN_REFERENCE is the git reference for the GSGEN3 framework bin repo"
    echo -e "    -h shows this text"
    echo -e "(o) -i INFRASTRUCTURE_REFERENCE is the git reference for the config repo"
    echo -e "(o) -p if the product directories should not be included"
    echo -e "(o) -s GSGEN_STARTUP_REFERENCE is the git reference for the GSGEN3 framework startup repo"
    echo -e "\nDEFAULTS:\n"
    echo -e "CONFIG_REFERENCE = ${PRODUCT_CONFIG_REFERENCE_DEFAULT}"
    echo -e "INFRASTRUCTURE_REFERENCE = ${PRODUCT_INFRASTRUCTURE_REFERENCE_DEFAULT}"
    echo -e "GSGEN_BIN_REFERENCE = ${GSGEN_BIN_REFERENCE_DEFAULT}"
    echo -e "GSGEN_STARTUP_REFERENCE = ${GSGEN_STARTUP_REFERENCE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1. AID/PRODUCT details are assumed to be already defined via environment variables"
    echo -e ""
    RESULT=1
    exit
}

EXCLUDE_AID_DIRECTORIES="false"
EXCLUDE_PRODUCT_DIRECTORIES="false"
# Parse options
while getopts ":ac:g:hi:ps:" opt; do
    case $opt in
        a)
            EXCLUDE_AID_DIRECTORIES="true"
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

# Check for required context
if [[ -z "${AID}" ]]; then
    echo "AID not defined"
    usage
fi

# Save for later steps
echo "PRODUCT_CONFIG_REFERENCE=${PRODUCT_CONFIG_REFERENCE}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_INFRASTRUCTURE_REFERENCE=${PRODUCT_INFRASTRUCTURE_REFERENCE}" >> ${WORKSPACE}/context.properties

# Create the top level directory representing the account
mkdir ${AID}
cd ${AID}
mkdir config infrastructure

if [[ !("${EXCLUDE_PRODUCT_DIRECTORIES}" == "true") ]]; then

    # Pull in the product config repo
    git clone https://${!PRODUCT_GIT_CREDENTIALS_VAR}@${PRODUCT_GIT_DNS}/${PRODUCT_GIT_ORG}/${PRODUCT_CONFIG_REPO} config/temp
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
 	    echo "Can't fetch the ${PRODUCT} config repo, exiting..."
 	    exit
    fi

    # Check out the required config information
    pushd config/temp > /dev/null 2>&1
    git checkout ${PRODUCT_CONFIG_REFERENCE}
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
	    echo "Can't checkout ${PRODUCT_CONFIG_REFERENCE} in the config repo, exiting..."
	    exit
    fi
    echo "PRODUCT_CONFIG_COMMIT=$(git rev-parse HEAD)" >> ${WORKSPACE}/context.properties
    popd > /dev/null 2>&1

    if [[ -d config/temp/${PRODUCT} ]]; then
        # Product repo contains the account and product config
        mv config/temp/* config
        mv config/temp/.git* config
        rm -rf config/temp
    else
        # Product repo contains only the product config
        mv config/temp config/${PRODUCT}
    fi
fi

if [[ !("${EXCLUDE_AID_DIRECTORIES}" == "true") ]]; then
    if [[ ! -d config/${AID} ]]; then
        # Pull in the account config repo
        git clone https://${!AID_GIT_CREDENTIALS_VAR}@${AID_GIT_DNS}/${AID_GIT_ORG}/${AID_CONFIG_REPO} -b master config/${AID}
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the ${AID} config repo, exiting..."
            exit
        fi
    fi
fi

if [[ ! -d config/bin ]]; then
    # Pull in the default GSGEN repo if not overridden by product
    if [[ -d config/${PRODUCT}/bin ]]; then
        mkdir config/bin
        cp -rp config/${PRODUCT}/bin config/bin
    else
        git clone https://${GSGEN_GIT_DNS}/${GSGEN_GIT_ORG}/${GSGEN_BIN_REPO} -b ${GSGEN_BIN_REFERENCE} config/bin
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the GSGEN repo, exiting..."
            exit
        fi
    fi
fi

if [[ !("${EXCLUDE_PRODUCT_DIRECTORIES}" == "true") ]]; then
    
    # Pull in the product infrastructure repo
    git clone https://${!PRODUCT_GIT_CREDENTIALS_VAR}@${PRODUCT_GIT_DNS}/${PRODUCT_GIT_ORG}/${PRODUCT_INFRASTRUCTURE_REPO} infrastructure/temp
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
	    echo "Can't fetch the ${PRODUCT} infrastructure repo, exiting..."
	    exit
    fi

    # Check out the required infrastructure information
    pushd infrastructure/temp > /dev/null 2>&1
    git checkout ${PRODUCT_INFRASTRUCTURE_REFERENCE}
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
	    echo "Can't checkout ${PRODUCT_INFRASTRUCTURE_REFERENCE} in the infrastructure repo, exiting..."
	    exit
    fi
    echo "PRODUCT_INFRASTRUCTURE_COMMIT=$(git rev-parse HEAD)" >> ${WORKSPACE}/context.properties
    popd > /dev/null 2>&1

    if [[ -d infrastructure/temp/${PRODUCT} ]]; then
        # Product repo contains the account and product infrastructure
        mv infrastructure/temp/* config
        mv infrastructure/temp/.git* config
        rm -rf infrastructure/temp
    else
        # Product repo contains only the product config
        mv infrastructure/temp infrastructure/${PRODUCT}
    fi
fi

if [[ !("${EXCLUDE_AID_DIRECTORIES}" == "true") ]]; then
    if [[ ! -d infrastructure/${AID} ]]; then
        # Pull in the account infrastructure repo
        git clone https://${!AID_GIT_CREDENTIALS_VAR}@${AID_GIT_DNS}/${AID_GIT_ORG}/${AID_INFRASTRUCTURE_REPO} -b master infrastructure/${AID}
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the ${AID} infrastructure repo, exiting..."
            exit
        fi
    fi
fi

if [[ ! -d infrastructure/startup ]]; then
    # Pull in the default GSGEN startup repo if not overridden by product
    if [[ -d infrastructure/${PRODUCT}/startup ]]; then
        cp -rp infrastructure/${PRODUCT}/startup infrastructure/startup
    else
        git clone https://${GSGEN_GIT_DNS}/${GSGEN_GIT_ORG}/${GSGEN_STARTUP_REPO} -b ${GSGEN_STARTUP_REFERENCE} infrastructure/startup
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the GSGEN startup repo, exiting..."
            exit
        fi
    fi
fi

# All good
RESULT=0

