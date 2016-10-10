#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

CYBER_REFERENCE_DEFAULT="master"
GSGEN_BIN_REFERENCE_DEFAULT="master"
function usage() {
    echo -e "\nConstruct the integrator directory tree" 
    echo -e "\nUsage: $(basename $0) -c CYBER_REFERENCE -g GSGEN_BIN_REFERENCE"
    echo -e "\nwhere\n"
    echo -e "(o) -i CYBER_REFERENCE is the git reference for the cyber account repo"
    echo -e "(o) -g GSGEN_BIN_REFERENCE is the git reference for the GSGEN3 framework bin repo"
    echo -e "    -h shows this text"
    echo -e "\nDEFAULTS:\n"
    echo -e "CYBER_REFERENCE = ${CYBER_REFERENCE_DEFAULT}"
    echo -e "GSGEN_BIN_REFERENCE = ${GSGEN_BIN_REFERENCE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e ""
    exit
}

# Parse options
while getopts ":c:g:h" opt; do
    case $opt in
        c)
            CYBER_REFERENCE="${OPTARG}"
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
CYBER_REFERENCE="${CYBER_REFERENCE:-$CYBER_REFERENCE_DEFAULT}"
GSGEN_BIN_REFERENCE="${GSGEN_BIN_REFERENCE:-$GSGEN_BIN_REFERENCE_DEFAULT}"

# Save for later steps
echo "CYBER_REFERENCE=${CYBER_REFERENCE}" >> ${WORKSPACE}/context.properties

# Pull in the integrator repo
git clone https://${!CID_GIT_CREDENTIALS_VAR}@${CID_GIT_DNS}/${CID_GIT_ORG}/${CID_REPO} ${CID}
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
    echo "Can't fetch the cyber repo, exiting..."
    exit
fi

# Pull in the default GSGEN repo
git clone https://${GSGEN_GIT_DNS}/${GSGEN_GIT_ORG}/${GSGEN_BIN_REPO} -b ${GSGEN_BIN_REFERENCE} gsgen
RESULT=$?
if [[ ${RESULT} -ne 0 ]]; then
    echo "Can't fetch the GSGEN repo, exiting..."
    exit
fi

# All good
RESULT=0

