#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

function usage() {
    echo -e "\nDetermine key settings for an account/project/segment" 
    echo -e "\nUsage: $(basename $0) -a OAID -p PROJECT -c SEGMENT"
    echo -e "\nwhere\n"
    echo -e "(o) -a OAID is the organisation account id e.g. \"env01\""
    echo -e "(o) -c SEGMENT is the SEGMENT name e.g. \"production\""
    echo -e "    -h shows this text"
    echo -e "(o) -p PROJECT is the project id e.g. \"eticket\""
    echo -e "\nNOTES:\n"
    echo -e "1) The setting values are saved in context.properties in the current directory"
    echo -e ""
    RESULT=1
    exit
}

# Parse options
while getopts ":a:p:h" opt; do
    case $opt in
        a)
            OAID="${OPTARG}"
            ;;
        c)
            SEGMENT="${OPTARG}"
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

# Determine the SEGMENT - normally the same as the environment
if [[ -z "${SEGMENT}" ]]; then
    SEGMENT=${ENVIRONMENT}
fi

SEGMENT=${SEGMENT,,}
SEGMENT_UPPER=${SEGMENT^^}

# Determine the account from the project/SEGMENT combination
# if not already defined or provided on the command line
if [[ -z "${OAID}" ]]; then
    OAID_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_OAID"
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
    AWS_SECRET_ACCESS_KEY="${ACC_AWS_SECRET_ACCESS_KEY}"
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
if [[ -z "${PROJECT_CODE_REPO}" ]]; then
    PROJECT_CODE_REPO_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_CODE_REPO"
    if [[ "${!PROJECT_CODE_REPO_VAR}" == "" ]]; then
        PROJECT_CODE_REPO_VAR="${PROJECT_UPPER}_CODE_REPO"
    fi
    PROJECT_CODE_REPO="${!PROJECT_CODE_REPO_VAR}"
fi
if [[ -z "${PROJECT_CONFIG_REPO}" ]]; then
    PROJECT_CONFIG_REPO_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_CONFIG_REPO"
    if [[ "${!PROJECT_CONFIG_REPO_VAR}" == "" ]]; then
        PROJECT_CONFIG_REPO_VAR="${PROJECT_UPPER}_CONFIG_REPO"
    fi
    PROJECT_CONFIG_REPO="${!PROJECT_CONFIG_REPO_VAR}"
fi
if [[ -z "${PROJECT_INFRASTRUCTURE_REPO}" ]]; then
    PROJECT_INFRASTRUCTURE_REPO_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_INFRASTRUCTURE_REPO"
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

# Determine the deployment tag
if [[ -n "${DEPLOYMENT_NUMBER}" ]]; then
    DEPLOYMENT_TAG="d${DEPLOYMENT_NUMBER}-${SEGMENT}"
else
    DEPLOYMENT_TAG="d${BUILD_NUMBER}-${SEGMENT}"
fi

# Basic details for git commits/slack notification (enhanced by other scripts)
DETAIL_MESSAGE="project=${PROJECT}, environment=${ENVIRONMENT}"
if [[ "${SEGMENT}" != "${ENVIRONMENT}" ]]; then DETAIL_MESSAGE="${DETAIL_MESSAGE}, segment=${SEGMENT}"; fi
if [[ -n "${TIER}" ]];      then DETAIL_MESSAGE="${DETAIL_MESSAGE}, tier=${TIER}"; fi
if [[ -n "${COMPONENT}" ]]; then DETAIL_MESSAGE="${DETAIL_MESSAGE}, component=${COMPONENT}"; fi
if [[ -n "${SLICE}" ]];     then DETAIL_MESSAGE="${DETAIL_MESSAGE}, slice=${SLICE}"; fi
if [[ -n "${SLICES}" ]];    then DETAIL_MESSAGE="${DETAIL_MESSAGE}, slices=${SLICES}"; fi
if [[ -n "${TASK}" ]];      then DETAIL_MESSAGE="${DETAIL_MESSAGE}, task=${TASK}"; fi
if [[ -n "${GIT_USER}" ]];  then DETAIL_MESSAGE="${DETAIL_MESSAGE}, user=${GIT_USER}"; fi

# Save for future steps
echo "OAID=${OAID}" >> ${WORKSPACE}/context.properties
echo "PROJECT=${PROJECT}" >> ${WORKSPACE}/context.properties
echo "SEGMENT=${SEGMENT}" >> ${WORKSPACE}/context.properties
echo "SLICE=${SLICE}" >> ${WORKSPACE}/context.properties
echo "SLICES=${SLICES}" >> ${WORKSPACE}/context.properties
echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" >> ${WORKSPACE}/context.properties
echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" >> ${WORKSPACE}/context.properties
echo "OAID_CONFIG_REPO=${OAID_CONFIG_REPO}" >> ${WORKSPACE}/context.properties
echo "OAID_INFRASTRUCTURE_REPO=${OAID_INFRASTRUCTURE_REPO}" >> ${WORKSPACE}/context.properties
echo "PROJECT_CODE_REPO=${PROJECT_CODE_REPO}" >> ${WORKSPACE}/context.properties
echo "PROJECT_CONFIG_REPO=${PROJECT_CONFIG_REPO}" >> ${WORKSPACE}/context.properties
echo "PROJECT_INFRASTRUCTURE_REPO=${PROJECT_INFRASTRUCTURE_REPO}" >> ${WORKSPACE}/context.properties
echo "GIT_USER=${GIT_USER}" >> ${WORKSPACE}/context.properties
echo "GIT_EMAIL=${GIT_EMAIL}" >> ${WORKSPACE}/context.properties
echo "DEPLOYMENT_TAG=${DEPLOYMENT_TAG}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

