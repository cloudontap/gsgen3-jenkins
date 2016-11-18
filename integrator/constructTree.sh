#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

INTEGRATOR_REFERENCE_DEFAULT="master"
GSGEN_BIN_REFERENCE_DEFAULT="master"
function usage() {
    echo -e "\nConstruct the integrator directory tree" 
    echo -e "\nUsage: $(basename $0) -i INTEGRATOR_REFERENCE -g GSGEN_BIN_REFERENCE"
    echo -e "\nwhere\n"
    echo -e "(o) -g GSGEN_BIN_REFERENCE is the git reference for the GSGEN3 framework bin repo"
    echo -e "    -h shows this text"
    echo -e "(o) -i INTEGRATOR_REFERENCE is the git reference for the integrator repo"
    echo -e "\nDEFAULTS:\n"
    echo -e "INTEGRATOR_REFERENCE = ${INTEGRATOR_REFERENCE_DEFAULT}"
    echo -e "GSGEN_BIN_REFERENCE = ${GSGEN_BIN_REFERENCE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e ""
    exit
}

# Parse options
while getopts ":c:g:h" opt; do
    case $opt in
        c)
            INTEGRATOR_REFERENCE="${OPTARG}"
            ;;
        g)
            GSGEN_BIN_REFERENCE="${OPTARG}"
            ;;
        h)
            usage
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
INTEGRATOR_REFERENCE="${INTEGRATOR_REFERENCE:-$INTEGRATOR_REFERENCE_DEFAULT}"
GSGEN_BIN_REFERENCE="${GSGEN_BIN_REFERENCE:-$GSGEN_BIN_REFERENCE_DEFAULT}"

# Save for later steps
echo "INTEGRATOR_REFERENCE=${INTEGRATOR_REFERENCE}" >> ${WORKSPACE}/context.properties

# Pull in the integrator repo
git clone https://${!INTEGRATOR_GIT_CREDENTIALS_VAR}@${INTEGRATOR_GIT_DNS}/${INTEGRATOR_GIT_ORG}/${INTEGRATOR_REPO} ${INTEGRATOR}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
    echo -e "\nCan't fetch the integrator repo"
    exit
fi

# Pull in the default GSGEN repo
git clone https://${GSGEN_GIT_DNS}/${GSGEN_GIT_ORG}/${GSGEN_BIN_REPO} -b ${GSGEN_BIN_REFERENCE} gsgen
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
    echo -e "\nCan't fetch the GSGEN repo"
    exit
fi

# All good
RESULT=0

