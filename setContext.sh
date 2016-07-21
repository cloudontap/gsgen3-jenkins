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
PROJECT=${PROJECT:-$(echo ${JOB_NAME} | cut -d '-' -f 1)}

PROJECT=${PROJECT,,}
PROJECT_UPPER=${PROJECT^^}

# Determine the SEGMENT - normally the same as the environment
SEGMENT=${SEGMENT:-$ENVIRONMENT}

SEGMENT=${SEGMENT,,}
SEGMENT_UPPER=${SEGMENT^^}

# Determine the account from the project/segment combination
# if not already defined or provided on the command line
if [[ -z "${OAID}" ]]; then
    OAID_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_OAID"
    if [[ -z "${!OAID_VAR}" ]]; then
        OAID_VAR="${PROJECT_UPPER}_OAID"
    fi
    OAID="${!OAID_VAR}"
fi

OAID=${OAID,,}
OAID_UPPER=${OAID^^}

# Defaults for github
GITHUB_DNS="${GITHUB_DNS:-github.com}"
GITHUB_API_DNS="${GITHUB_API_DNS:-api.$GITHUB_DNS}"

# Defaults for docker
DOCKER_DNS="${DOCKER_DNS:-docker.${OAID}.gosource.com.au}"
DOCKER_API_DNS="${DOCKER_API_DNS:-$DOCKER_DNS}"

# Defaults for gsgen
# TODO: Add ability for OAID/PROJECT override
GSGEN_GIT_DNS="${GSGEN_GIT_DNS:-github.com}"
GSGEN_GIT_ORG="${GSGEN_GIT_ORG:-cloudontap}"
GSGEN_BIN_REPO="${GSGEN_BIN_REPO:-gsgen3.git}"
GSGEN_STARTUP_REPO="${GSGEN_STARTUP_REPO:-gsgen3-startup.git}"

# Determine the account git provider
if [[ -z "${OAID_GIT_PROVIDER}" ]]; then
    OAID_GIT_PROVIDER_VAR="${OAID_UPPER}_GIT_PROVIDER"
    OAID_GIT_PROVIDER="${!OAID_GIT_PROVIDER_VAR}"
    OAID_GIT_PROVIDER="${OAID_GIT_PROVIDER:-GITHUB}"
fi

OAID_GIT_USER_VAR="${OAID_GIT_PROVIDER}_USER"
OAID_GIT_PASSWORD_VAR="${OAID_GIT_PROVIDER}_PASSWORD"
OAID_GIT_CREDENTIALS_VAR="${OAID_GIT_PROVIDER}_CREDENTIALS"

OAID_GIT_ORG_VAR="${OAID_GIT_PROVIDER}_ORG"
OAID_GIT_ORG="${!OAID_GIT_ORG_VAR}"

OAID_GIT_DNS_VAR="${OAID_GIT_PROVIDER}_DNS"
OAID_GIT_DNS="${!OAID_GIT_DNS_VAR}"

OAID_GIT_API_DNS_VAR="${OAID_GIT_PROVIDER}_API_DNS"
OAID_GIT_API_DNS="${!OAID_GIT_API_DNS_VAR}"

# Determine the account access credentials
OAID_AWS_ACCESS_KEY_ID_VAR="${OAID_UPPER}_AWS_ACCESS_KEY_ID"
OAID_AWS_SECRET_ACCESS_KEY_VAR="${OAID_UPPER}_AWS_SECRET_ACCESS_KEY"

# Determine account repos
if [[ -z "${OAID_CONFIG_REPO}" ]]; then
    OAID_CONFIG_REPO_VAR="${OAID_UPPER}_CONFIG_REPO"
    OAID_CONFIG_REPO="${!OAID_CONFIG_REPO_VAR}"
fi
if [[ -z "${OAID_INFRASTRUCTURE_REPO}" ]]; then
    OAID_INFRASTRUCTURE_REPO_VAR="${OAID_UPPER}_INFRASTRUCTURE_REPO"
    OAID_INFRASTRUCTURE_REPO="${!OAID_INFRASTRUCTURE_REPO_VAR}"
fi

# Determine slices
SLICE_LIST="${SLICE_LIST:-$SLICES}"
SLICE_LIST="${SLICE_LIST:-$SLICE}"
SLICE_ARRAY=($SLICE_LIST)
BUILD_SLICE="${BUILD_SLICE:-$SLICE}"
BUILD_SLICE="${BUILD_SLICE:-${SLICE_ARRAY[0]}}"
CODE_SLICE=$(echo "${BUILD_SLICE:-NOSLICE}" | tr "-" "_")

# Determine the project git provider
if [[ -z "${PROJECT_GIT_PROVIDER}" ]]; then
    PROJECT_GIT_PROVIDER_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_GIT_PROVIDER"
    if [[ -z "${!PROJECT_GIT_PROVIDER_VAR}" ]]; then
        PROJECT_GIT_PROVIDER_VAR="${PROJECT_UPPER}_GIT_PROVIDER"
    fi
    PROJECT_GIT_PROVIDER="${!PROJECT_GIT_PROVIDER_VAR}"
    PROJECT_GIT_PROVIDER="${PROJECT_GIT_PROVIDER:-$OAID_GIT_PROVIDER}"
fi

PROJECT_GIT_USER_VAR="${PROJECT_GIT_PROVIDER}_USER"
PROJECT_GIT_PASSWORD_VAR="${PROJECT_GIT_PROVIDER}_PASSWORD"
PROJECT_GIT_CREDENTIALS_VAR="${PROJECT_GIT_PROVIDER}_CREDENTIALS"

PROJECT_GIT_ORG_VAR="${PROJECT_GIT_PROVIDER}_ORG"
PROJECT_GIT_ORG="${!PROJECT_GIT_ORG_VAR}"

PROJECT_GIT_DNS_VAR="${PROJECT_GIT_PROVIDER}_DNS"
PROJECT_GIT_DNS="${!PROJECT_GIT_DNS_VAR}"

PROJECT_GIT_API_DNS_VAR="${PROJECT_GIT_PROVIDER}_API_DNS"
PROJECT_GIT_API_DNS="${!PROJECT_GIT_API_DNS_VAR}"

# Determine the project local docker provider
if [[ -z "${PROJECT_DOCKER_PROVIDER}" ]]; then
    PROJECT_DOCKER_PROVIDER_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_DOCKER_PROVIDER"
    if [[ -z "${!PROJECT_DOCKER_PROVIDER_VAR}" ]]; then
        PROJECT_DOCKER_PROVIDER_VAR="${PROJECT_UPPER}_DOCKER_PROVIDER"
    fi
    PROJECT_DOCKER_PROVIDER="${!PROJECT_DOCKER_PROVIDER_VAR}"
    PROJECT_DOCKER_PROVIDER="${PROJECT_DOCKER_PROVIDER:-DOCKER}"
fi

PROJECT_DOCKER_USER_VAR="${PROJECT_DOCKER_PROVIDER}_USER"
PROJECT_DOCKER_PASSWORD_VAR="${PROJECT_DOCKER_PROVIDER}_PASSWORD"
PROJECT_DOCKER_CREDENTIALS_VAR="${PROJECT_DOCKER_PROVIDER}_CREDENTIALS"

PROJECT_DOCKER_EMAIL_VAR="${PROJECT_DOCKER_PROVIDER}_EMAIL"
PROJECT_DOCKER_EMAIL="${!PROJECT_DOCKER_EMAIL_VAR}"

PROJECT_DOCKER_DNS_VAR="${PROJECT_DOCKER_PROVIDER}_DNS"
PROJECT_DOCKER_DNS="${!PROJECT_DOCKER_DNS_VAR}"

PROJECT_DOCKER_API_DNS_VAR="${PROJECT_DOCKER_PROVIDER}_API_DNS"
PROJECT_DOCKER_API_DNS="${!PROJECT_DOCKER_API_DNS_VAR}"

# Determine the project remote docker provider (for sourcing new images)
if [[ -z "${PROJECT_REMOTE_DOCKER_PROVIDER}" ]]; then
    PROJECT_REMOTE_DOCKER_PROVIDER_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_REMOTE_DOCKER_PROVIDER"
    if [[ -z "${!PROJECT_REMOTE_DOCKER_PROVIDER_VAR}" ]]; then
        PROJECT_REMOTE_DOCKER_PROVIDER_VAR="${PROJECT_UPPER}_REMOTE_DOCKER_PROVIDER"
    fi
    PROJECT_REMOTE_DOCKER_PROVIDER="${!PROJECT_REMOTE_DOCKER_PROVIDER_VAR}"
    PROJECT_REMOTE_DOCKER_PROVIDER="${PROJECT_REMOTE_DOCKER_PROVIDER:-$PROJECT_DOCKER_PROVIDER}"
fi

PROJECT_REMOTE_DOCKER_USER_VAR="${PROJECT_REMOTE_DOCKER_PROVIDER}_USER"
PROJECT_REMOTE_DOCKER_PASSWORD_VAR="${PROJECT_REMOTE_DOCKER_PROVIDER}_PASSWORD"
PROJECT_REMOTE_DOCKER_CREDENTIALS_VAR="${PROJECT_REMOTE_DOCKER_PROVIDER}_CREDENTIALS"

PROJECT_REMOTE_DOCKER_EMAIL_VAR="${PROJECT_REMOTE_DOCKER_PROVIDER}_EMAIL"
PROJECT_REMOTE_DOCKER_EMAIL="${!PROJECT_REMOTE_DOCKER_EMAIL_VAR}"

PROJECT_REMOTE_DOCKER_DNS_VAR="${PROJECT_REMOTE_DOCKER_PROVIDER}_DNS"
PROJECT_REMOTE_DOCKER_DNS="${!PROJECT_REMOTE_DOCKER_DNS_VAR}"

PROJECT_REMOTE_DOCKER_API_DNS_VAR="${PROJECT_REMOTE_DOCKER_PROVIDER}_API_DNS"
PROJECT_REMOTE_DOCKER_API_DNS="${!PROJECT_REMOTE_DOCKER_API_DNS_VAR}"

# Determine project repos
if [[ -z "${PROJECT_CONFIG_REPO}" ]]; then
    PROJECT_CONFIG_REPO_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_CONFIG_REPO"
    if [[ -z "${!PROJECT_CONFIG_REPO_VAR}" ]]; then
        PROJECT_CONFIG_REPO_VAR="${PROJECT_UPPER}_CONFIG_REPO"
    fi
    PROJECT_CONFIG_REPO="${!PROJECT_CONFIG_REPO_VAR}"
fi
if [[ -z "${PROJECT_INFRASTRUCTURE_REPO}" ]]; then
    PROJECT_INFRASTRUCTURE_REPO_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_INFRASTRUCTURE_REPO"
    if [[ -z "${!PROJECT_INFRASTRUCTURE_REPO_VAR}" ]]; then
        PROJECT_INFRASTRUCTURE_REPO_VAR="${PROJECT_UPPER}_INFRASTRUCTURE_REPO"
    fi
    PROJECT_INFRASTRUCTURE_REPO="${!PROJECT_INFRASTRUCTURE_REPO_VAR}"
fi

# Determine the project code git provider
if [[ -z "${PROJECT_CODE_GIT_PROVIDER}" ]]; then
    PROJECT_CODE_GIT_PROVIDER_VAR="${PROJECT_UPPER}_${SEGMENT_UPPER}_GIT_PROVIDER"
    if [[ -z "${!PROJECT_CODE_GIT_PROVIDER_VAR}" ]]; then
        PROJECT_CODE_GIT_PROVIDER_VAR="${PROJECT_UPPER}_GIT_PROVIDER"
    fi
    PROJECT_CODE_GIT_PROVIDER="${!PROJECT_CODE_GIT_PROVIDER_VAR}"
    PROJECT_CODE_GIT_PROVIDER="${PROJECT_CODE_GIT_PROVIDER:-$PROJECT_GIT_PROVIDER}"
fi

PROJECT_CODE_GIT_USER_VAR="${PROJECT_CODE_GIT_PROVIDER}_USER"
PROJECT_CODE_GIT_PASSWORD_VAR="${PROJECT_CODE_GIT_PROVIDER}_PASSWORD"
PROJECT_CODE_GIT_CREDENTIALS_VAR="${PROJECT_CODE_GIT_PROVIDER}_CREDENTIALS"

PROJECT_CODE_GIT_ORG_VAR="${PROJECT_CODE_GIT_PROVIDER}_ORG"
PROJECT_CODE_GIT_ORG="${!PROJECT_CODE_GIT_ORG_VAR}"

PROJECT_CODE_GIT_DNS_VAR="${PROJECT_CODE_GIT_PROVIDER}_DNS"
PROJECT_CODE_GIT_DNS="${!PROJECT_CODE_GIT_DNS_VAR}"

PROJECT_CODE_GIT_API_DNS_VAR="${PROJECT_CODE_GIT_PROVIDER}_API_DNS"
PROJECT_CODE_GIT_API_DNS="${!PROJECT_CODE_GIT_API_DNS_VAR}"

# Determine code repo
if [[ -z "${PROJECT_CODE_REPO}" ]]; then
    PROJECT_CODE_REPO_VAR="${PROJECT_UPPER}_${CODE_SLICE^^}_CODE_REPO"
    if [[ -z "${!PROJECT_CODE_REPO_VAR}" ]]; then
        PROJECT_CODE_REPO_VAR="${PROJECT_UPPER}_CODE_REPO"
    fi
    PROJECT_CODE_REPO="${!PROJECT_CODE_REPO_VAR}"
fi

# Determine who to include as the author if git updates required
GIT_USER="${GIT_USER:-$BUILD_USER}"
GIT_USER="${GIT_USER:-$GIT_USER_DEFAULT}"
GIT_EMAIL="${GIT_EMAIL:-$BUILD_USER_EMAIL}"
GIT_EMAIL="${GIT_EMAIL:-$GIT_EMAIL_DEFAULT}"

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
if [[ -n "${TASKS}" ]];     then DETAIL_MESSAGE="${DETAIL_MESSAGE}, tasks=${TASKS}"; fi
if [[ -n "${GIT_USER}" ]];  then DETAIL_MESSAGE="${DETAIL_MESSAGE}, user=${GIT_USER}"; fi

# Save for future steps
echo "OAID=${OAID}" >> ${WORKSPACE}/context.properties
echo "PROJECT=${PROJECT}" >> ${WORKSPACE}/context.properties
echo "SEGMENT=${SEGMENT}" >> ${WORKSPACE}/context.properties
echo "SLICE=${SLICE}" >> ${WORKSPACE}/context.properties
echo "SLICES=${SLICES}" >> ${WORKSPACE}/context.properties
echo "SLICE_LIST=${SLICE_LIST}" >> ${WORKSPACE}/context.properties
echo "BUILD_SLICE=${BUILD_SLICE}" >> ${WORKSPACE}/context.properties

echo "OAID_GIT_PROVIDER=${OAID_GIT_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "OAID_GIT_USER_VAR=${OAID_GIT_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "OAID_GIT_PASSWORD_VAR=${OAID_GIT_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "OAID_GIT_CREDENTIALS_VAR=${OAID_GIT_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "OAID_GIT_ORG=${OAID_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "OAID_GIT_DNS=${OAID_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "OAID_GIT_API_DNS=${OAID_GIT_API_DNS}" >> ${WORKSPACE}/context.properties

echo "OAID_AWS_ACCESS_KEY_ID_VAR=${OAID_AWS_ACCESS_KEY_ID_VAR}" >> ${WORKSPACE}/context.properties
echo "OAID_AWS_SECRET_ACCESS_KEY_VAR=${OAID_AWS_SECRET_ACCESS_KEY_VAR}" >> ${WORKSPACE}/context.properties

echo "OAID_CONFIG_REPO=${OAID_CONFIG_REPO}" >> ${WORKSPACE}/context.properties
echo "OAID_INFRASTRUCTURE_REPO=${OAID_INFRASTRUCTURE_REPO}" >> ${WORKSPACE}/context.properties

echo "PROJECT_GIT_PROVIDER=${PROJECT_GIT_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "PROJECT_GIT_USER_VAR=${PROJECT_GIT_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_GIT_PASSWORD_VAR=${PROJECT_GIT_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_GIT_CREDENTIALS_VAR=${PROJECT_GIT_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_GIT_ORG=${PROJECT_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "PROJECT_GIT_DNS=${PROJECT_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "PROJECT_GIT_API_DNS=${PROJECT_GIT_API_DNS}" >> ${WORKSPACE}/context.properties

echo "PROJECT_DOCKER_PROVIDER=${PROJECT_DOCKER_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "PROJECT_DOCKER_USER_VAR=${PROJECT_DOCKER_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_DOCKER_PASSWORD_VAR=${PROJECT_DOCKER_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_DOCKER_CREDENTIALS_VAR=${PROJECT_DOCKER_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_DOCKER_EMAIL=${PROJECT_DOCKER_EMAIL}" >> ${WORKSPACE}/context.properties
echo "PROJECT_DOCKER_DNS=${PROJECT_DOCKER_DNS}" >> ${WORKSPACE}/context.properties
echo "PROJECT_DOCKER_API_DNS=${PROJECT_DOCKER_API_DNS}" >> ${WORKSPACE}/context.properties

echo "PROJECT_REMOTE_DOCKER_PROVIDER=${PROJECT_REMOTE_DOCKER_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "PROJECT_REMOTE_DOCKER_USER_VAR=${PROJECT_REMOTE_DOCKER_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_REMOTE_DOCKER_PASSWORD_VAR=${PROJECT_REMOTE_DOCKER_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_REMOTE_DOCKER_CREDENTIALS_VAR=${PROJECT_REMOTE_DOCKER_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_REMOTE_DOCKER_EMAIL=${PROJECT_REMOTE_DOCKER_EMAIL}" >> ${WORKSPACE}/context.properties
echo "PROJECT_REMOTE_DOCKER_DNS=${PROJECT_REMOTE_DOCKER_DNS}" >> ${WORKSPACE}/context.properties
echo "PROJECT_REMOTE_DOCKER_API_DNS=${PROJECT_REMOTE_DOCKER_API_DNS}" >> ${WORKSPACE}/context.properties

echo "PROJECT_CONFIG_REPO=${PROJECT_CONFIG_REPO}" >> ${WORKSPACE}/context.properties
echo "PROJECT_INFRASTRUCTURE_REPO=${PROJECT_INFRASTRUCTURE_REPO}" >> ${WORKSPACE}/context.properties

echo "PROJECT_CODE_GIT_PROVIDER=${PROJECT_CODE_GIT_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "PROJECT_CODE_GIT_USER_VAR=${PROJECT_CODE_GIT_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_CODE_GIT_PASSWORD_VAR=${PROJECT_CODE_GIT_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_CODE_GIT_CREDENTIALS_VAR=${PROJECT_CODE_GIT_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "PROJECT_CODE_GIT_ORG=${PROJECT_CODE_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "PROJECT_CODE_GIT_DNS=${PROJECT_CODE_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "PROJECT_CODE_GIT_API_DNS=${PROJECT_CODE_GIT_API_DNS}" >> ${WORKSPACE}/context.properties

echo "PROJECT_CODE_REPO=${PROJECT_CODE_REPO}" >> ${WORKSPACE}/context.properties

echo "GIT_USER=${GIT_USER}" >> ${WORKSPACE}/context.properties
echo "GIT_EMAIL=${GIT_EMAIL}" >> ${WORKSPACE}/context.properties
echo "DEPLOYMENT_TAG=${DEPLOYMENT_TAG}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

