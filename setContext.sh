#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi
JENKINS_DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

function usage() {
    echo -e "\nDetermine key settings for an tenant/account/product/segment" 
    echo -e "\nUsage: $(basename $0) -t TENANT -a ACCOUNT -p PRODUCT -c SEGMENT"
    echo -e "\nwhere\n"
    echo -e "(o) -a ACCOUNT is the tenant account name e.g. \"env01\""
    echo -e "(o) -c SEGMENT is the SEGMENT name e.g. \"production\""
    echo -e "    -h shows this text"
    echo -e "(o) -p PRODUCT is the product name e.g. \"eticket\""
    echo -e "(o) -t TENANT is the tenant name e.g. \"env\""
    echo -e "\nNOTES:\n"
    echo -e "1. The setting values are saved in context.properties in the current directory"
    echo -e ""
    exit
}

# Parse options
while getopts ":a:c:hp:t:" opt; do
    case $opt in
        a)
            ACCOUNT="${OPTARG}"
            ;;
        c)
            SEGMENT="${OPTARG}"
            ;;
        h)
            usage
            ;;
        p)
            PRODUCT="${OPTARG}"
            ;;
        t)
            TENANT="${OPTARG}"
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

# Determine the tenant/product/segment from the job name
# if not already defined or provided on the command line
# Only parts of the jobname starting with "cot-" are
# considered and the "cot-" prefix is removed to give the
# actual segment/product/tenant id
JOB_PATH=($(echo "${JOB_NAME}" | tr "/" " "))
PARTS_ARRAY=()
COT_PREFIX="cot-"
for PART in ${JOB_PATH[@]}; do
    if [[ "${PART}" =~ ^${COT_PREFIX}* ]]; then
        PARTS_ARRAY+=("${PART#${COT_PREFIX}}")
    fi
done
PARTS_COUNT="${#PARTS_ARRAY[@]}"

if [[ "${PARTS_COUNT}" -gt 3 ]]; then
    # Assume its integrator/tenant/product/segment
    INTEGRATOR=${INTEGRATOR:-${PARTS_ARRAY[${PARTS_COUNT}-4]}}
    TENANT=${TENANT:-${PARTS_ARRAY[${PARTS_COUNT}-3]}}
    PRODUCT=${PRODUCT:-${PARTS_ARRAY[${PARTS_COUNT}-2]}}
    SEGMENT=${SEGMENT:-${PARTS_ARRAY[${PARTS_COUNT}-1]}}
fi
if [[ "${PARTS_COUNT}" -gt 2 ]]; then
    # Assume its integrator/tenant/product
    INTEGRATOR=${INTEGRATOR:-${PARTS_ARRAY[${PARTS_COUNT}-3]}}
    TENANT=${TENANT:-${PARTS_ARRAY[${PARTS_COUNT}-2]}}
    PRODUCT=${PRODUCT:-${PARTS_ARRAY[${PARTS_COUNT}-1]}}
fi
if [[ "${PARTS_COUNT}" -gt 1 ]]; then
    # Assume its product and segment
    PRODUCT=${PRODUCT:-${PARTS_ARRAY[${PARTS_COUNT}-2]}}
    SEGMENT=${SEGMENT:-${PARTS_ARRAY[${PARTS_COUNT}-1]}}
fi
if [[ "${PARTS_COUNT}" -gt 0 ]]; then
    # Assume its the product
    PRODUCT=${PRODUCT:-${PARTS_ARRAY[${PARTS_COUNT}-1]}}
else
    # Default before use of folder plugin was for product to be first token in job name
    PRODUCT=${PRODUCT:-$(echo ${JOB_NAME} | cut -d '-' -f 1)}
fi


TENANT=${TENANT,,}
TENANT_UPPER=${TENANT^^}

PRODUCT=${PRODUCT,,}
PRODUCT_UPPER=${PRODUCT^^}

# Determine the SEGMENT - normally the same as the environment
SEGMENT=${SEGMENT:-$ENVIRONMENT}

SEGMENT=${SEGMENT,,}
SEGMENT_UPPER=${SEGMENT^^}

# Determine the account from the product/segment combination
# if not already defined or provided on the command line
if [[ -z "${ACCOUNT}" ]]; then
    ACCOUNT_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_ACCOUNT"
    if [[ -z "${!ACCOUNT_VAR}" ]]; then
        ACCOUNT_VAR="${PRODUCT_UPPER}_ACCOUNT"
    fi
    ACCOUNT="${!ACCOUNT_VAR}"
fi

ACCOUNT=${ACCOUNT,,}
ACCOUNT_UPPER=${ACCOUNT^^}

# Default "GITHUB" git provider
GITHUB_DNS="${GITHUB_DNS:-github.com}"

# Determine who to include as the author if git updates required
GIT_USER="${GIT_USER:-$BUILD_USER}"
GIT_USER="${GIT_USER:-$GIT_USER_DEFAULT}"
GIT_USER="${GIT_USER:-alm}"
GIT_EMAIL="${GIT_EMAIL:-$BUILD_USER_EMAIL}"
GIT_EMAIL="${GIT_EMAIL:-$GIT_EMAIL_DEFAULT}"

# Defaults for gsgen
# TODO: Add ability for ACCOUNT/PRODUCT override
GSGEN_GIT_DNS="${GSGEN_GIT_DNS:-github.com}"
GSGEN_GIT_ORG="${GSGEN_GIT_ORG:-codeontap}"
GSGEN_BIN_REPO="${GSGEN_BIN_REPO:-gsgen3.git}"
GSGEN_STARTUP_REPO="${GSGEN_STARTUP_REPO:-gsgen3-startup.git}"

# Determine the slice list and optional corresponding code tags and repos
# A slice can be followed by an optional code tag separated by an "!"
# A code tag will be ignored if no code repo has been defined for the slice
TAG_SEPARATOR='!'
SLICE_ARRAY=()
CODE_TAG_ARRAY=()
CODE_REPO_ARRAY=()
for CURRENT_SLICE in ${SLICES:-${SLICE}}; do
    SLICE_PART="${CURRENT_SLICE%%${TAG_SEPARATOR}*}"
    TAG_PART="${CURRENT_SLICE##*${TAG_SEPARATOR}}"
    if [[ (-n "${CODE_TAG}") && ("${#SLICE_ARRAY[@]}" -eq 0) ]]; then
        # Permit override of first tag - easier if only one repo involved
        TAG_PART="${CODE_TAG}"
        CURRENT_SLICE="${SLICE_PART}${TAG_SEPARATOR}${TAG_PART}"
    fi
        
    SLICE_ARRAY+=("${SLICE_PART,,}")

    if [[ (-n "${TAG_PART}") && ( "${CURRENT_SLICE}" =~ .+${TAG_SEPARATOR}.+ ) ]]; then
        CODE_TAG_ARRAY+=("${TAG_PART,,}")        
    else
        CODE_TAG_ARRAY+=("?")
    fi

    # Determine code repo for the slice - there may be none
    CODE_SLICE=$(echo "${SLICE_PART^^}" | tr "-" "_")
    PRODUCT_CODE_REPO_VAR="${PRODUCT_UPPER}_${CODE_SLICE^^}_CODE_REPO"
    if [[ -z "${!PRODUCT_CODE_REPO_VAR}" ]]; then
        PRODUCT_CODE_REPO_VAR="${PRODUCT_UPPER}_CODE_REPO"
    fi
    CODE_REPO_PART="${!PRODUCT_CODE_REPO_VAR}"

    CODE_REPO_ARRAY+=("${CODE_REPO_PART:-?}")
done

# Determine the account access credentials
. ${JENKINS_DIR}/setAWSCredentials.sh ${ACCOUNT_UPPER}

# Determine the account git provider
if [[ -z "${ACCOUNT_GIT_PROVIDER}" ]]; then
    ACCOUNT_GIT_PROVIDER_VAR="${ACCOUNT_UPPER}_GIT_PROVIDER"
    ACCOUNT_GIT_PROVIDER="${!ACCOUNT_GIT_PROVIDER_VAR}"
    ACCOUNT_GIT_PROVIDER="${ACCOUNT_GIT_PROVIDER:-GITHUB}"
fi

ACCOUNT_GIT_USER_VAR="${ACCOUNT_GIT_PROVIDER}_USER"
ACCOUNT_GIT_PASSWORD_VAR="${ACCOUNT_GIT_PROVIDER}_PASSWORD"
ACCOUNT_GIT_CREDENTIALS_VAR="${ACCOUNT_GIT_PROVIDER}_CREDENTIALS"

ACCOUNT_GIT_ORG_VAR="${ACCOUNT_GIT_PROVIDER}_ORG"
ACCOUNT_GIT_ORG="${!ACCOUNT_GIT_ORG_VAR}"

ACCOUNT_GIT_DNS_VAR="${ACCOUNT_GIT_PROVIDER}_DNS"
ACCOUNT_GIT_DNS="${!ACCOUNT_GIT_DNS_VAR}"

ACCOUNT_GIT_API_DNS_VAR="${ACCOUNT_GIT_PROVIDER}_API_DNS"
ACCOUNT_GIT_API_DNS="${!ACCOUNT_GIT_API_DNS_VAR:-api.$ACCOUNT_GIT_DNS}"

# Determine account repos
if [[ -z "${ACCOUNT_CONFIG_REPO}" ]]; then
    ACCOUNT_CONFIG_REPO_VAR="${ACCOUNT_UPPER}_CONFIG_REPO"
    ACCOUNT_CONFIG_REPO="${!ACCOUNT_CONFIG_REPO_VAR}"
fi
if [[ -z "${ACCOUNT_INFRASTRUCTURE_REPO}" ]]; then
    ACCOUNT_INFRASTRUCTURE_REPO_VAR="${ACCOUNT_UPPER}_INFRASTRUCTURE_REPO"
    ACCOUNT_INFRASTRUCTURE_REPO="${!ACCOUNT_INFRASTRUCTURE_REPO_VAR}"
fi

# Determine the product git provider
if [[ -z "${PRODUCT_GIT_PROVIDER}" ]]; then
    PRODUCT_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_GIT_PROVIDER"
    if [[ -z "${!PRODUCT_GIT_PROVIDER_VAR}" ]]; then
        PRODUCT_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_GIT_PROVIDER"
    fi
    PRODUCT_GIT_PROVIDER="${!PRODUCT_GIT_PROVIDER_VAR}"
    PRODUCT_GIT_PROVIDER="${PRODUCT_GIT_PROVIDER:-$ACCOUNT_GIT_PROVIDER}"
fi

PRODUCT_GIT_USER_VAR="${PRODUCT_GIT_PROVIDER}_USER"
PRODUCT_GIT_PASSWORD_VAR="${PRODUCT_GIT_PROVIDER}_PASSWORD"
PRODUCT_GIT_CREDENTIALS_VAR="${PRODUCT_GIT_PROVIDER}_CREDENTIALS"

PRODUCT_GIT_ORG_VAR="${PRODUCT_GIT_PROVIDER}_ORG"
PRODUCT_GIT_ORG="${!PRODUCT_GIT_ORG_VAR}"

PRODUCT_GIT_DNS_VAR="${PRODUCT_GIT_PROVIDER}_DNS"
PRODUCT_GIT_DNS="${!PRODUCT_GIT_DNS_VAR}"

PRODUCT_GIT_API_DNS_VAR="${PRODUCT_GIT_PROVIDER}_API_DNS"
PRODUCT_GIT_API_DNS="${!PRODUCT_GIT_API_DNS_VAR:-api.$PRODUCT_GIT_DNS}"

# Determine the product local docker provider
if [[ -z "${PRODUCT_DOCKER_PROVIDER}" ]]; then
    PRODUCT_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_DOCKER_PROVIDER"
    if [[ -z "${!PRODUCT_DOCKER_PROVIDER_VAR}" ]]; then
        PRODUCT_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_DOCKER_PROVIDER"
    fi
    PRODUCT_DOCKER_PROVIDER="${!PRODUCT_DOCKER_PROVIDER_VAR}"
    PRODUCT_DOCKER_PROVIDER="${PRODUCT_DOCKER_PROVIDER:-$ACCOUNT}"
fi

PRODUCT_DOCKER_USER_VAR="${PRODUCT_DOCKER_PROVIDER}_USER"
PRODUCT_DOCKER_PASSWORD_VAR="${PRODUCT_DOCKER_PROVIDER}_PASSWORD"

PRODUCT_DOCKER_DNS_VAR="${PRODUCT_DOCKER_PROVIDER}_DNS"
PRODUCT_DOCKER_DNS="${!PRODUCT_DOCKER_DNS_VAR}"

PRODUCT_DOCKER_API_DNS_VAR="${PRODUCT_DOCKER_PROVIDER}_API_DNS"
PRODUCT_DOCKER_API_DNS="${!PRODUCT_DOCKER_API_DNS_VAR:-$PRODUCT_DOCKER_DNS}"

# Determine the product remote docker provider (for sourcing new images)
if [[ -z "${PRODUCT_REMOTE_DOCKER_PROVIDER}" ]]; then
    PRODUCT_REMOTE_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_REMOTE_DOCKER_PROVIDER"
    if [[ -z "${!PRODUCT_REMOTE_DOCKER_PROVIDER_VAR}" ]]; then
        PRODUCT_REMOTE_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_REMOTE_DOCKER_PROVIDER"
    fi
    PRODUCT_REMOTE_DOCKER_PROVIDER="${!PRODUCT_REMOTE_DOCKER_PROVIDER_VAR}"
    PRODUCT_REMOTE_DOCKER_PROVIDER="${PRODUCT_REMOTE_DOCKER_PROVIDER:-$PRODUCT_DOCKER_PROVIDER}"
fi

PRODUCT_REMOTE_DOCKER_USER_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER}_USER"
PRODUCT_REMOTE_DOCKER_PASSWORD_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER}_PASSWORD"

PRODUCT_REMOTE_DOCKER_DNS_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER}_DNS"
PRODUCT_REMOTE_DOCKER_DNS="${!PRODUCT_REMOTE_DOCKER_DNS_VAR}"

PRODUCT_REMOTE_DOCKER_API_DNS_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER}_API_DNS"
PRODUCT_REMOTE_DOCKER_API_DNS="${!PRODUCT_REMOTE_DOCKER_API_DNS_VAR:-$PRODUCT_REMOTE_DOCKER_DNS}"

# Determine product repos
if [[ -z "${PRODUCT_CONFIG_REPO}" ]]; then
    PRODUCT_CONFIG_REPO_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_CONFIG_REPO"
    if [[ -z "${!PRODUCT_CONFIG_REPO_VAR}" ]]; then
        PRODUCT_CONFIG_REPO_VAR="${PRODUCT_UPPER}_CONFIG_REPO"
    fi
    PRODUCT_CONFIG_REPO="${!PRODUCT_CONFIG_REPO_VAR}"
fi
if [[ -z "${PRODUCT_INFRASTRUCTURE_REPO}" ]]; then
    PRODUCT_INFRASTRUCTURE_REPO_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_INFRASTRUCTURE_REPO"
    if [[ -z "${!PRODUCT_INFRASTRUCTURE_REPO_VAR}" ]]; then
        PRODUCT_INFRASTRUCTURE_REPO_VAR="${PRODUCT_UPPER}_INFRASTRUCTURE_REPO"
    fi
    PRODUCT_INFRASTRUCTURE_REPO="${!PRODUCT_INFRASTRUCTURE_REPO_VAR}"
fi

# Determine the product code git provider
if [[ -z "${PRODUCT_CODE_GIT_PROVIDER}" ]]; then
    PRODUCT_CODE_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_GIT_PROVIDER"
    if [[ -z "${!PRODUCT_CODE_GIT_PROVIDER_VAR}" ]]; then
        PRODUCT_CODE_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_GIT_PROVIDER"
    fi
    PRODUCT_CODE_GIT_PROVIDER="${!PRODUCT_CODE_GIT_PROVIDER_VAR}"
    PRODUCT_CODE_GIT_PROVIDER="${PRODUCT_CODE_GIT_PROVIDER:-$PRODUCT_GIT_PROVIDER}"
fi

PRODUCT_CODE_GIT_USER_VAR="${PRODUCT_CODE_GIT_PROVIDER}_USER"
PRODUCT_CODE_GIT_PASSWORD_VAR="${PRODUCT_CODE_GIT_PROVIDER}_PASSWORD"
PRODUCT_CODE_GIT_CREDENTIALS_VAR="${PRODUCT_CODE_GIT_PROVIDER}_CREDENTIALS"

PRODUCT_CODE_GIT_ORG_VAR="${PRODUCT_CODE_GIT_PROVIDER}_ORG"
PRODUCT_CODE_GIT_ORG="${!PRODUCT_CODE_GIT_ORG_VAR}"

PRODUCT_CODE_GIT_DNS_VAR="${PRODUCT_CODE_GIT_PROVIDER}_DNS"
PRODUCT_CODE_GIT_DNS="${!PRODUCT_CODE_GIT_DNS_VAR}"

PRODUCT_CODE_GIT_API_DNS_VAR="${PRODUCT_CODE_GIT_PROVIDER}_API_DNS"
PRODUCT_CODE_GIT_API_DNS="${!PRODUCT_CODE_GIT_API_DNS_VAR:-api.$PRODUCT_CODE_GIT_DNS}"

# Determine the deployment tag
RELEASE_TAG="r${BUILD_NUMBER}-${SEGMENT}"
if [[ -n "${RELEASE_NUMBER}" ]]; then
    RELEASE_TAG="r${RELEASE_NUMBER}-${SEGMENT}"
fi

# Basic details for git commits/slack notification (enhanced by other scripts)
DETAIL_MESSAGE="product=${PRODUCT}"
if [[ -n "${ENVIRONMENT}" ]]; then DETAIL_MESSAGE="${DETAIL_MESSAGE}, environment=${ENVIRONMENT}"; fi
if [[ "${SEGMENT}" != "${ENVIRONMENT}" ]]; then DETAIL_MESSAGE="${DETAIL_MESSAGE}, segment=${SEGMENT}"; fi
if [[ -n "${TIER}" ]];      then DETAIL_MESSAGE="${DETAIL_MESSAGE}, tier=${TIER}"; fi
if [[ -n "${COMPONENT}" ]]; then DETAIL_MESSAGE="${DETAIL_MESSAGE}, component=${COMPONENT}"; fi
if [[ -n "${SLICE}" ]];     then DETAIL_MESSAGE="${DETAIL_MESSAGE}, slice=${SLICE}"; fi
if [[ -n "${SLICES}" ]];    then DETAIL_MESSAGE="${DETAIL_MESSAGE}, slices=${SLICES}"; fi
if [[ -n "${TASK}" ]];      then DETAIL_MESSAGE="${DETAIL_MESSAGE}, task=${TASK}"; fi
if [[ -n "${TASKS}" ]];     then DETAIL_MESSAGE="${DETAIL_MESSAGE}, tasks=${TASKS}"; fi
if [[ -n "${GIT_USER}" ]];  then DETAIL_MESSAGE="${DETAIL_MESSAGE}, user=${GIT_USER}"; fi
if [[ -n "${MODE}" ]];      then DETAIL_MESSAGE="${DETAIL_MESSAGE}, mode=${MODE}"; fi

# Save for future steps
echo "TENANT=${TENANT}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT=${ACCOUNT}" >> ${WORKSPACE}/context.properties
echo "PRODUCT=${PRODUCT}" >> ${WORKSPACE}/context.properties
if [[ -n "${SEGMENT}" ]]; then echo "SEGMENT=${SEGMENT}" >> ${WORKSPACE}/context.properties; fi
if [[ -n "${SLICE}" ]]; then echo "SLICE=${SLICE}" >> ${WORKSPACE}/context.properties; fi
if [[ -n "${SLICES}" ]]; then echo "SLICES=${SLICES}" >> ${WORKSPACE}/context.properties; fi

echo "GIT_USER=${GIT_USER}" >> ${WORKSPACE}/context.properties
echo "GIT_EMAIL=${GIT_EMAIL}" >> ${WORKSPACE}/context.properties

echo "GSGEN_GIT_DNS=${GSGEN_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "GSGEN_GIT_ORG=${GSGEN_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "GSGEN_BIN_REPO=${GSGEN_BIN_REPO}" >> ${WORKSPACE}/context.properties
echo "GSGEN_STARTUP_REPO=${GSGEN_STARTUP_REPO}" >> ${WORKSPACE}/context.properties

echo "SLICE_LIST=${SLICE_ARRAY[@]}" >> ${WORKSPACE}/context.properties
echo "CODE_TAG_LIST=${CODE_TAG_ARRAY[@]}" >> ${WORKSPACE}/context.properties
echo "CODE_REPO_LIST=${CODE_REPO_ARRAY[@]}" >> ${WORKSPACE}/context.properties

echo "ACCOUNT_AWS_ACCESS_KEY_ID_VAR=${AWS_CRED_AWS_ACCESS_KEY_ID_VAR}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_AWS_SECRET_ACCESS_KEY_VAR=${AWS_CRED_AWS_SECRET_ACCESS_KEY_VAR}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_TEMP_AWS_ACCESS_KEY_ID=${AWS_CRED_TEMP_AWS_ACCESS_KEY_ID}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_TEMP_AWS_SECRET_ACCESS_KEY=${AWS_CRED_TEMP_AWS_SECRET_ACCESS_KEY}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_TEMP_AWS_SESSION_TOKEN=${AWS_CRED_TEMP_AWS_SESSION_TOKEN}" >> ${WORKSPACE}/context.properties

echo "ACCOUNT_GIT_PROVIDER=${ACCOUNT_GIT_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_GIT_USER_VAR=${ACCOUNT_GIT_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_GIT_PASSWORD_VAR=${ACCOUNT_GIT_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_GIT_CREDENTIALS_VAR=${ACCOUNT_GIT_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_GIT_ORG=${ACCOUNT_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_GIT_DNS=${ACCOUNT_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_GIT_API_DNS=${ACCOUNT_GIT_API_DNS}" >> ${WORKSPACE}/context.properties

echo "ACCOUNT_CONFIG_REPO=${ACCOUNT_CONFIG_REPO}" >> ${WORKSPACE}/context.properties
echo "ACCOUNT_INFRASTRUCTURE_REPO=${ACCOUNT_INFRASTRUCTURE_REPO}" >> ${WORKSPACE}/context.properties

echo "PRODUCT_GIT_PROVIDER=${PRODUCT_GIT_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_GIT_USER_VAR=${PRODUCT_GIT_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_GIT_PASSWORD_VAR=${PRODUCT_GIT_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_GIT_CREDENTIALS_VAR=${PRODUCT_GIT_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_GIT_ORG=${PRODUCT_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_GIT_DNS=${PRODUCT_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_GIT_API_DNS=${PRODUCT_GIT_API_DNS}" >> ${WORKSPACE}/context.properties

echo "PRODUCT_DOCKER_PROVIDER=${PRODUCT_DOCKER_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_DOCKER_USER_VAR=${PRODUCT_DOCKER_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_DOCKER_PASSWORD_VAR=${PRODUCT_DOCKER_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_DOCKER_DNS=${PRODUCT_DOCKER_DNS}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_DOCKER_API_DNS=${PRODUCT_DOCKER_API_DNS}" >> ${WORKSPACE}/context.properties

echo "PRODUCT_REMOTE_DOCKER_PROVIDER=${PRODUCT_REMOTE_DOCKER_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_REMOTE_DOCKER_USER_VAR=${PRODUCT_REMOTE_DOCKER_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_REMOTE_DOCKER_PASSWORD_VAR=${PRODUCT_REMOTE_DOCKER_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_REMOTE_DOCKER_DNS=${PRODUCT_REMOTE_DOCKER_DNS}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_REMOTE_DOCKER_API_DNS=${PRODUCT_REMOTE_DOCKER_API_DNS}" >> ${WORKSPACE}/context.properties

echo "PRODUCT_CONFIG_REPO=${PRODUCT_CONFIG_REPO}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_INFRASTRUCTURE_REPO=${PRODUCT_INFRASTRUCTURE_REPO}" >> ${WORKSPACE}/context.properties

echo "PRODUCT_CODE_GIT_PROVIDER=${PRODUCT_CODE_GIT_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_CODE_GIT_USER_VAR=${PRODUCT_CODE_GIT_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_CODE_GIT_PASSWORD_VAR=${PRODUCT_CODE_GIT_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_CODE_GIT_CREDENTIALS_VAR=${PRODUCT_CODE_GIT_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_CODE_GIT_ORG=${PRODUCT_CODE_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_CODE_GIT_DNS=${PRODUCT_CODE_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_CODE_GIT_API_DNS=${PRODUCT_CODE_GIT_API_DNS}" >> ${WORKSPACE}/context.properties

echo "RELEASE_TAG=${RELEASE_TAG}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# All good
RESULT=0

