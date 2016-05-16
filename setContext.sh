#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

function usage() {
    echo -e "\nDetermine key settings for an account/project" 
    echo -e "\nUsage: $(basename $0) -a OAID -p PROJECT -c CONTAINER"
    echo -e "\nwhere\n"
    echo -e "(o) -a OAID is the organisation account id e.g. \"env01\""
    echo -e "(o) -c CONTAINER is the container name e.g. \"production\""
    echo -e "    -h shows this text"
    echo -e "(o) -p PROJECT is the project id e.g. \"eticket\""
    echo -e "\nNOTES:\n"
    echo -e "1) The setting values are saved in context.ref in the current directory"
    echo -e ""
    exit
}

# Parse options
while getopts ":a:p:h" opt; do
    case $opt in
        a)
            OAID="${OPTARG}"
            ;;
        c)
            CONTAINER="${OPTARG}"
            ;;
        h)
            usage
            ;;
        p)
            PROJECT="${OPTARG}"
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

# Determine the project from the job name 
# if not already defined or provided on the command line
if [[ -z "${PROJECT}" ]]; then
    PROJECT=$(echo ${JOB_NAME} | cut -d '-' -f 1)
fi

PROJECT=${PROJECT,,}
PROJECT_UPPER=${PROJECT^^}

# Determine the container - normally the same as the environment
if [[ -z "${CONTAINER}" ]]; then
    CONTAINER=${ENVIRONMENT}
fi

CONTAINER=${CONTAINER,,}
CONTAINER_UPPER=${CONTAINER^^}

# Determine the account from the project/container combination
# if not already defined or provided on the command line
if [[ -z "${OAID}" ]]; then
    OAID_VAR="${PROJECT_UPPER}_${CONTAINER_UPPER}_OAID"
    if [[ "${!OAID_VAR}" == "" ]]; then 
        OAID_VAR="${PROJECT_UPPER}_OAID"
    fi
    OAID="${!OAID_VAR}"
fi

OAID=${OAID,,}
OAID_UPPER=${OAID^^}

# Determine the access credentials for the target account
if [[ -z "${AWS_ACCESS_KEY_ID}" ]]; then
    AWS_ACCESS_KEY_ID_VAR="${OAID_UPPER}_AWS_ACCESS_KEY_ID"
    AWS_ACCESS_KEY_ID="${!AWS_ACCESS_KEY_ID_VAR}"
fi

if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then
    AWS_SECRET_ACCESS_KEY_VAR="${OAID_UPPER}_AWS_SECRET_ACCESS_KEY"
    AWS_SECRET_ACCESS_KEY="${!AWS_SECRET_ACCESS_KEY_VAR}"
fi

# Determine account repos
if [[ -z "${OAID_CONFIG_REPO}" ]]; then
    OAID_CONFIG_REPO_VAR="${OAID_UPPER}_CONFIG_REPO"
    OAID_CONFIG_REPO="${!OAID_CONFIG_REPO_VAR}"
fi
if [[ -z "${OAID_INFRASTRUCTURE_REPO}" ]]; then
    OAID_INFRASTRUCTURE_REPO_VAR="${OAID_UPPER}_INFRASTRUCTURE_REPO"
    OAID_INFRASTRUCTURE_REPO="${!OAID_INFRASTRUCTURE_REPO_VAR}"
fi

# Determine project repos
if [[ -z "${PROJECT_CONFIG_REPO}" ]]; then
    PROJECT_CONFIG_REPO_VAR="${PROJECT_UPPER}_${CONTAINER_UPPER}_CONFIG_REPO"
    if [[ "${!PROJECT_CONFIG_REPO_VAR}" == "" ]]; then 
        PROJECT_CONFIG_REPO_VAR="${PROJECT_UPPER}_CONFIG_REPO"
    fi
    PROJECT_CONFIG_REPO="${!PROJECT_CONFIG_REPO_VAR}"
fi
if [[ -z "${PROJECT_INFRASTRUCTURE_REPO}" ]]; then
    PROJECT_INFRASTRUCTURE_REPO_VAR="${PROJECT_UPPER}_${CONTAINER_UPPER}_INFRASTRUCTURE_REPO"
    if [[ "${!PROJECT_INFRASTRUCTURE_REPO_VAR}" == "" ]]; then 
        PROJECT_INFRASTRUCTURE_REPO_VAR="${PROJECT_UPPER}_INFRASTRUCTURE_REPO"
    fi
    PROJECT_INFRASTRUCTURE_REPO="${!PROJECT_INFRASTRUCTURE_REPO_VAR}"
fi

# Determine who to include as the author if git updates required
if [[ -z "${GIT_USER}" ]]; then
    GIT_USER="${BUILD_USER}"
fi
if [[ -z "${GIT_USER}" ]]; then
    GIT_USER="${GIT_USER_DEFAULT}"
fi
if [[ -z "${GIT_EMAIL}" ]]; then
    GIT_EMAIL="${BUILD_USER_EMAIL}"
fi
if [[ -z "${GIT_EMAIL}" ]]; then
    GIT_EMAIL="${GIT_EMAIL_DEFAULT}"
fi

# Export for Save for future steps
export OAID="${OAID}"
export PROJECT="${PROJECT}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export OAID_CONFIG_REPO="${OAID_CONFIG_REPO}"
export OAID_INFRASTRUCTURE_REPO="${OAID_INFRASTRUCTURE_REPO}"
export PROJECT_CONFIG_REPO="${PROJECT_CONFIG_REPO}"
export PROJECT_INFRASTRUCTURE_REPO="${PROJECT_INFRASTRUCTURE_REPO}"
export GIT_USER="${GIT_USER}"
export GIT_EMAIL="${GIT_EMAIL}"

# Save for future steps
echo "OAID=${OAID}" >> ${WORKSPACE}/context.ref
echo "PROJECT=${PROJECT}" >> ${WORKSPACE}/context.ref
echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" >> ${WORKSPACE}/context.ref
echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" >> ${WORKSPACE}/context.ref
echo "OAID_CONFIG_REPO=${OAID_CONFIG_REPO}" >> ${WORKSPACE}/context.ref
echo "OAID_INFRASTRUCTURE_REPO=${OAID_INFRASTRUCTURE_REPO}" >> ${WORKSPACE}/context.ref
echo "PROJECT_CONFIG_REPO=${PROJECT_CONFIG_REPO}" >> ${WORKSPACE}/context.ref
echo "PROJECT_INFRASTRUCTURE_REPO=${PROJECT_INFRASTRUCTURE_REPO}" >> ${WORKSPACE}/context.ref
echo "GIT_USER=${GIT_USER}" >> ${WORKSPACE}/context.ref
echo "GIT_EMAIL=${GIT_EMAIL}" >> ${WORKSPACE}/context.ref

