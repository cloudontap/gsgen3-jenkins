#!/bin/bash

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

PROJECT_CONFIG_REFERENCE_DEFAULT="master"
PROJECT_INFRASTRUCTURE_REFERENCE_DEFAULT="master"
function usage() {
  echo -e "\nConstruct the account directory tree" 
  echo -e "\nUsage: $(basename $0) -c CONFIG_REFERENCE -i INFRASTRUCTURE_REFERENCE -x"
  echo -e "\nwhere\n"
  echo -e "(o) -c CONFIG_REFERENCE is the git reference for the config repo"
  echo -e "    -h shows this text"
  echo -e "(o) -i INFRASTRUCTURE_REFERENCE is the git reference for the config repo"
  echo -e "(o) -x if the project tree should not be included"
  echo -e "\nDEFAULTS:\n"
  echo -e "CONFIG_REFERENCE = ${PROJECT_CONFIG_REFERENCE_DEFAULT}"
  echo -e "INFRASTRUCTURE_REFERENCE = ${PROJECT_INFRASTRUCTURE_REFERENCE_DEFAULT}"
  echo -e "\nNOTES:\n"
  echo -e "1) OAID/PROJECT details are assumed to be already defined via environment variables"
  echo -e ""
  RESULT=1
  exit
}

EXCLUDE_PROJECT_TREE="false"
# Parse options
while getopts ":c:hi:x" opt; do
  case $opt in
    c)
      PROJECT_CONFIG_REFERENCE="${OPTARG}"
      ;;
    h)
      usage
      ;;
    i)
      PROJECT_INFRASTRUCTURE_REFERENCE="${OPTARG}"
      ;;
    x)
      EXCLUDE_PROJECT_TREE="true"
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

if [[ -z "${PROJECT_CONFIG_REFERENCE}" ]]; then
    PROJECT_CONFIG_REFERENCE="${PROJECT_CONFIG_REFERENCE_DEFAULT}"
fi
if [[ -z "${PROJECT_INFRASTRUCTURE_REFERENCE}" ]]; then
    PROJECT_INFRASTRUCTURE_REFERENCE="${PROJECT_INFRASTRUCTURE_REFERENCE_DEFAULT}"
fi

# Check for required context
if [[ -z "${OAID}" ]]; then
    echo "OAID not defined"
    usage
fi

# Create the top level directory representing the account
mkdir ${OAID}
cd ${OAID}
mkdir config infrastructure

if [[ !("${EXCLUDE_PROJECT_TREE}" == "true") ]]; then

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
    echo "PROJECT_CONFIG_COMMIT=$(git rev-parse HEAD)" >> ${WORKSPACE}/context.ref
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

if [[ ! -d config/${OAID} ]]; then
    # Pull in the account config repo
    git clone https://${GITHUB_USER}:${GITHUB_PASS}@${OAID_CONFIG_REPO} -b master config/${OAID}
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo "Can't fetch the ${OAID} config repo, exiting..."
        exit
    fi
fi

if [[ ! -d config/bin ]]; then
    # Pull in the default GSGEN repo if not overridden by project
    if [[ -d config/${PROJECT}/bin ]]; then
        mkdir config/bin
        cp -rp config/${PROJECT}/bin config/bin
    else
        git clone https://${GSGEN_BIN_REPO} -b master config/bin
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the GSGEN repo, exiting..."
            exit
        fi
    fi
fi

if [[ !("${EXCLUDE_PROJECT_TREE}" == "true") ]]; then
    
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
    echo "PROJECT_INFRASTRUCTURE_COMMIT=$(git rev-parse HEAD)" >> ${WORKSPACE}/context.ref
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

if [[ ! -d infrastructure/${OAID} ]]; then
    # Pull in the account infrastructure repo
    git clone https://${GITHUB_USER}:${GITHUB_PASS}@${OAID_INFRASTRUCTURE_REPO} -b master infrastructure/${OAID}
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo "Can't fetch the ${OAID} infrastructure repo, exiting..."
        exit
    fi
fi

if [[ ! -d infrastructure/startup ]]; then
    # Pull in the default GSGEN startup repo if not overridden by project
    if [[ -d infrastructure/${PROJECT}/startup ]]; then
        cp -rp infrastructure/${PROJECT}/startup infrastructure/startup
    else
        git clone https://${GSGEN_BIN_REPO} -b master infrastructure/startup
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't fetch the GSGEN startup repo, exiting..."
            exit
        fi
    fi
fi

