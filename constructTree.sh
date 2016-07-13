#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

PROJECT_CONFIG_REFERENCE_DEFAULT="master"
PROJECT_INFRASTRUCTURE_REFERENCE_DEFAULT="master"
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
    echo -e "(o) -p if the project directories should not be included"
    echo -e "(o) -s GSGEN_STARTUP_REFERENCE is the git reference for the GSGEN3 framework startup repo"
    echo -e "\nDEFAULTS:\n"
    echo -e "CONFIG_REFERENCE = ${PROJECT_CONFIG_REFERENCE_DEFAULT}"
    echo -e "INFRASTRUCTURE_REFERENCE = ${PROJECT_INFRASTRUCTURE_REFERENCE_DEFAULT}"
    echo -e "GSGEN_BIN_REFERENCE = ${GSGEN_BIN_REFERENCE_DEFAULT}"
    echo -e "GSGEN_STARTUP_REFERENCE = ${GSGEN_STARTUP_REFERENCE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1) OAID/PROJECT details are assumed to be already defined via environment variables"
    echo -e ""
    RESULT=1
    exit
}

EXCLUDE_OAID_DIRECTORIES="false"
EXCLUDE_PROJECT_DIRECTORIES="false"
# Parse options
while getopts ":ac:g:hi:ps:" opt; do
    case $opt in
        a)
            EXCLUDE_OAID_DIRECTORIES="true"
            ;;
        c)
            PROJECT_CONFIG_REFERENCE="${OPTARG}"
            ;;
        g)
            GSGEN_BIN_REFERENCE="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            PROJECT_INFRASTRUCTURE_REFERENCE="${OPTARG}"
            ;;
        p)
            EXCLUDE_PROJECT_DIRECTORIES="true"
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
PROJECT_CONFIG_REFERENCE="${PROJECT_CONFIG_REFERENCE:-$PROJECT_CONFIG_REFERENCE_DEFAULT}"
PROJECT_INFRASTRUCTURE_REFERENCE="${PROJECT_INFRASTRUCTURE_REFERENCE:-$PROJECT_INFRASTRUCTURE_REFERENCE_DEFAULT}"
GSGEN_BIN_REFERENCE="${GSGEN_BIN_REFERENCE:-$GSGEN_BIN_REFERENCE_DEFAULT}"
GSGEN_STARTUP_REFERENCE="${GSGEN_STARTUP_REFERENCE:-$GSGEN_STARTUP_REFERENCE_DEFAULT}"

# Check for required context
if [[ -z "${OAID}" ]]; then
    echo "OAID not defined"
    usage
fi

# Save for later steps
echo "PROJECT_CONFIG_REFERENCE=${PROJECT_CONFIG_REFERENCE}" >> ${WORKSPACE}/context.properties
echo "PROJECT_INFRASTRUCTURE_REFERENCE=${PROJECT_INFRASTRUCTURE_REFERENCE}" >> ${WORKSPACE}/context.properties

# Create the top level directory representing the account
mkdir ${OAID}
cd ${OAID}
mkdir config infrastructure

if [[ !("${EXCLUDE_PROJECT_DIRECTORIES}" == "true") ]]; then

    # Pull in the project config repo
    git clone https://${GITHUB_USER}:${GITHUB_PASS}@${PROJECT_CONFIG_REPO} config/temp
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
 	    echo "Can't fetch the ${PROJECT} config repo, exiting..."
 	    exit
    fi

    # Check out the required config information
    pushd config/temp > /dev/null 2>&1
    git checkout ${PROJECT_CONFIG_REFERENCE}
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
	    echo "Can't checkout ${PROJECT_CONFIG_REFERENCE} in the config repo, exiting..."
	    exit
    fi
    echo "PROJECT_CONFIG_COMMIT=$(git rev-parse HEAD)" >> ${WORKSPACE}/context.properties
    popd > /dev/null 2>&1

    if [[ -d config/temp/${PROJECT} ]]; then
        # Project repo contains the account and project config
        mv config/temp/* config
        mv config/temp/.git* config
        rm -rf config/temp
    else
        # Project repo contains only the project config
        mv config/temp config/${PROJECT}
    fi
fi

if [[ !("${EXCLUDE_OAID_DIRECTORIES}" == "true") ]]; then
    if [[ ! -d config/${OAID} ]]; then
        # Pull in the account config repo
        git clone https://${GITHUB_USER}:${GITHUB_PASS}@${OAID_CONFIG_REPO} -b master config/${OAID}
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the ${OAID} config repo, exiting..."
            exit
        fi
    fi
fi

if [[ ! -d config/bin ]]; then
    # Pull in the default GSGEN repo if not overridden by project
    if [[ -d config/${PROJECT}/bin ]]; then
        mkdir config/bin
        cp -rp config/${PROJECT}/bin config/bin
    else
        git clone https://${GSGEN_BIN_REPO} -b ${GSGEN_BIN_REFERENCE} config/bin
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the GSGEN repo, exiting..."
            exit
        fi
    fi
fi

if [[ !("${EXCLUDE_PROJECT_DIRECTORIES}" == "true") ]]; then
    
    # Pull in the project infrastructure repo
    git clone https://${GITHUB_USER}:${GITHUB_PASS}@${PROJECT_INFRASTRUCTURE_REPO} infrastructure/temp
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
	    echo "Can't fetch the ${PROJECT} infrastructure repo, exiting..."
	    exit
    fi

    # Check out the required infrastructure information
    pushd infrastructure/temp > /dev/null 2>&1
    git checkout ${PROJECT_INFRASTRUCTURE_REFERENCE}
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
	    echo "Can't checkout ${PROJECT_INFRASTRUCTURE_REFERENCE} in the infrastructure repo, exiting..."
	    exit
    fi
    echo "PROJECT_INFRASTRUCTURE_COMMIT=$(git rev-parse HEAD)" >> ${WORKSPACE}/context.properties
    popd > /dev/null 2>&1

    if [[ -d infrastructure/temp/${PROJECT} ]]; then
        # Project repo contains the account and project infrastructure
        mv infrastructure/temp/* config
        mv infrastructure/temp/.git* config
        rm -rf infrastructure/temp
    else
        # Project repo contains only the project config
        mv infrastructure/temp infrastructure/${PROJECT}
    fi
fi

if [[ !("${EXCLUDE_OAID_DIRECTORIES}" == "true") ]]; then
    if [[ ! -d infrastructure/${OAID} ]]; then
        # Pull in the account infrastructure repo
        git clone https://${GITHUB_USER}:${GITHUB_PASS}@${OAID_INFRASTRUCTURE_REPO} -b master infrastructure/${OAID}
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the ${OAID} infrastructure repo, exiting..."
            exit
        fi
    fi
fi

if [[ ! -d infrastructure/startup ]]; then
    # Pull in the default GSGEN startup repo if not overridden by project
    if [[ -d infrastructure/${PROJECT}/startup ]]; then
        cp -rp infrastructure/${PROJECT}/startup infrastructure/startup
    else
        git clone https://${GSGEN_STARTUP_REPO} -b ${GSGEN_STARTUP_REFERENCE} infrastructure/startup
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the GSGEN startup repo, exiting..."
            exit
        fi
    fi
fi

