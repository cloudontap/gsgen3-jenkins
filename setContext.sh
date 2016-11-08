#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

function usage() {
    echo -e "\nDetermine key settings for an tenant/account/product/segment" 
    echo -e "\nUsage: $(basename $0) -a AID -t TENANT -p PRODUCT -c SEGMENT"
    echo -e "\nwhere\n"
    echo -e "(o) -a AID is the tenant account id e.g. \"env01\""
    echo -e "(o) -c SEGMENT is the SEGMENT name e.g. \"production\""
    echo -e "    -h shows this text"
    echo -e "(o) -p PRODUCT is the product id e.g. \"eticket\""
    echo -e "(o) -t TENANT is the tenant id e.g. \"env\""
    echo -e "\nNOTES:\n"
    echo -e "1. The setting values are saved in context.properties in the current directory"
    echo -e ""
    exit
}

# Parse options
while getopts ":a:c:hp:t:" opt; do
    case $opt in
        a)
            AID="${OPTARG}"
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
PARTS=()
COT_PREFIX="cot-"
for PART in ${JOB_PATH[@]}; do
    if [[ "${PART}" =~ ^${COT_PREFIX}* ]]; then
        PART+=("${PART#${COT_PREFIX}}")
    fi
done
PARTS_COUNT="${#PARTS[@]}"

# Default before folder plugin was for product to be first token in job name
PRODUCT=${PRODUCT:-$(echo ${JOB_NAME} | cut -d '-' -f 1)}

if [[ "${PARTS_COUNT}" -gt 0 ]]; then
    # Assume its the product
    PRODUCT=${PRODUCT:-${PARTS[${PARTS_COUNT}-1]}}
fi

if [[ "${PARTS_COUNT}" -gt 1 ]]; then
    # Assume its product and segment
    PRODUCT=${PRODUCT:-${PARTS[${PARTS_COUNT}-2]}}
    SEGMENT=${SEGMENT:-${PARTS[${PARTS_COUNT}-1]}}
fi
if [[ "${PARTS_COUNT}" -gt 2 ]]; then
    # Assume its tenant/product/segment
    TENANT=${TENANT:-${PARTS[${PARTS_COUNT}-3]}}
    PRODUCT=${PRODUCT:-${PARTS[${PARTS_COUNT}-2]}}
    SEGMENT=${SEGMENT:-${PARTS[${PARTS_COUNT}-1]}}
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
if [[ -z "${AID}" ]]; then
    AID_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_AID"
    if [[ -z "${!AID_VAR}" ]]; then
        AID_VAR="${PRODUCT_UPPER}_AID"
    fi
    AID="${!AID_VAR}"
fi

AID=${AID,,}
AID_UPPER=${AID^^}

# Default "GITHUB" git provider
GITHUB_DNS="${GITHUB_DNS:-github.com}"
GITHUB_API_DNS="${GITHUB_API_DNS:-api.$GITHUB_DNS}"

# Default "DOCKER" docker registry provider
DOCKER_DNS="${DOCKER_DNS:-docker.${AID}.gosource.com.au}"
DOCKER_API_DNS="${DOCKER_API_DNS:-$DOCKER_DNS}"

# Determine who to include as the author if git updates required
GIT_USER="${GIT_USER:-$BUILD_USER}"
GIT_USER="${GIT_USER:-$GIT_USER_DEFAULT}"
GIT_USER="${GIT_USER:-alm}"
GIT_EMAIL="${GIT_EMAIL:-$BUILD_USER_EMAIL}"
GIT_EMAIL="${GIT_EMAIL:-$GIT_EMAIL_DEFAULT}"

# Defaults for gsgen
# TODO: Add ability for AID/PRODUCT override
GSGEN_GIT_DNS="${GSGEN_GIT_DNS:-github.com}"
GSGEN_GIT_ORG="${GSGEN_GIT_ORG:-codeontap}"
GSGEN_BIN_REPO="${GSGEN_BIN_REPO:-gsgen3.git}"
GSGEN_STARTUP_REPO="${GSGEN_STARTUP_REPO:-gsgen3-startup.git}"

# Determine slices
SLICE_LIST="${SLICES}"
SLICE_LIST="${SLICE_LIST:-$SLICE}"
SLICE_ARRAY=($SLICE_LIST)
BUILD_SLICE="${SLICE}"
BUILD_SLICE="${BUILD_SLICE:-${SLICE_ARRAY[0]}}"
CODE_SLICE=$(echo "${BUILD_SLICE:-NOSLICE}" | tr "-" "_")

# Determine the account access credentials
AID_AWS_ACCOUNT_ID_VAR="${AID_UPPER}_AWS_ACCOUNT_ID"
AID_AUTOMATION_USER_VAR="${AID_UPPER}_AUTOMATION_USER"
if [[ (-n ${!AID_AWS_ACCOUNT_ID_VAR}) && (-n ${!AID_AUTOMATION_USER_VAR}) ]]; then
    # Assume automation role using automation user access credentials
    # Note that the value for the user is just a way to obtain the access credentials
    # and doesn't have to be the same as the IAM user name
    AID_AWS_ACCESS_KEY_ID_VAR="${!AID_AUTOMATION_USER_VAR^^}_AWS_ACCESS_KEY_ID"
    AID_AWS_SECRET_ACCESS_KEY_VAR="${!AID_AUTOMATION_USER_VAR^^}_AWS_SECRET_ACCESS_KEY"
    export AWS_ACCESS_KEY_ID="${!AID_AWS_ACCESS_KEY_ID_VAR}"
    export AWS_SECRET_ACCESS_KEY="${!AID_AWS_SECRET_ACCESS_KEY_VAR}"
    if [[ (-n ${AWS_ACCESS_KEY_ID}) && (-n ${AWS_SECRET_ACCESS_KEY}) ]]; then
        TEMP_CREDENTIAL_FILE="$WORKSPACE/temp_aws_credentials.json"
        aws sts assume-role \
            --role-arn arn:aws:iam::${!AID_AWS_ACCOUNT_ID_VAR}:role/codeontap-automation \
            --role-session-name "$(echo $GIT_USER | tr -d ' ' )" \
            --output json > $TEMP_CREDENTIAL_FILE
        AID_TEMP_AWS_ACCESS_KEY_ID=$(cat $TEMP_CREDENTIAL_FILE | jq -r '.Credentials.AccessKeyId')
        AID_TEMP_AWS_SECRET_ACCESS_KEY=$(cat $TEMP_CREDENTIAL_FILE | jq -r '.Credentials.SecretAccessKey')
        AID_TEMP_AWS_SESSION_TOKEN=$(cat $TEMP_CREDENTIAL_FILE | jq -r '.Credentials.SessionToken')
        rm $TEMP_CREDENTIAL_FILE
    fi
else
    # Fallback is an access key in the account
    AID_AWS_ACCESS_KEY_ID_VAR="${AID_UPPER}_AWS_ACCESS_KEY_ID"
    AID_AWS_SECRET_ACCESS_KEY_VAR="${AID_UPPER}_AWS_SECRET_ACCESS_KEY"
fi

# Determine the account git provider
if [[ -z "${AID_GIT_PROVIDER}" ]]; then
    AID_GIT_PROVIDER_VAR="${AID_UPPER}_GIT_PROVIDER"
    AID_GIT_PROVIDER="${!AID_GIT_PROVIDER_VAR}"
    AID_GIT_PROVIDER="${AID_GIT_PROVIDER:-GITHUB}"
fi

AID_GIT_USER_VAR="${AID_GIT_PROVIDER}_USER"
AID_GIT_PASSWORD_VAR="${AID_GIT_PROVIDER}_PASSWORD"
AID_GIT_CREDENTIALS_VAR="${AID_GIT_PROVIDER}_CREDENTIALS"

AID_GIT_ORG_VAR="${AID_GIT_PROVIDER}_ORG"
AID_GIT_ORG="${!AID_GIT_ORG_VAR}"

AID_GIT_DNS_VAR="${AID_GIT_PROVIDER}_DNS"
AID_GIT_DNS="${!AID_GIT_DNS_VAR}"

AID_GIT_API_DNS_VAR="${AID_GIT_PROVIDER}_API_DNS"
AID_GIT_API_DNS="${!AID_GIT_API_DNS_VAR}"

# Determine account repos
if [[ -z "${AID_CONFIG_REPO}" ]]; then
    AID_CONFIG_REPO_VAR="${AID_UPPER}_CONFIG_REPO"
    AID_CONFIG_REPO="${!AID_CONFIG_REPO_VAR}"
fi
if [[ -z "${AID_INFRASTRUCTURE_REPO}" ]]; then
    AID_INFRASTRUCTURE_REPO_VAR="${AID_UPPER}_INFRASTRUCTURE_REPO"
    AID_INFRASTRUCTURE_REPO="${!AID_INFRASTRUCTURE_REPO_VAR}"
fi

# Determine the product git provider
if [[ -z "${PRODUCT_GIT_PROVIDER}" ]]; then
    PRODUCT_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_GIT_PROVIDER"
    if [[ -z "${!PRODUCT_GIT_PROVIDER_VAR}" ]]; then
        PRODUCT_GIT_PROVIDER_VAR="${PRODUCT_UPPER}_GIT_PROVIDER"
    fi
    PRODUCT_GIT_PROVIDER="${!PRODUCT_GIT_PROVIDER_VAR}"
    PRODUCT_GIT_PROVIDER="${PRODUCT_GIT_PROVIDER:-$AID_GIT_PROVIDER}"
fi

PRODUCT_GIT_USER_VAR="${PRODUCT_GIT_PROVIDER}_USER"
PRODUCT_GIT_PASSWORD_VAR="${PRODUCT_GIT_PROVIDER}_PASSWORD"
PRODUCT_GIT_CREDENTIALS_VAR="${PRODUCT_GIT_PROVIDER}_CREDENTIALS"

PRODUCT_GIT_ORG_VAR="${PRODUCT_GIT_PROVIDER}_ORG"
PRODUCT_GIT_ORG="${!PRODUCT_GIT_ORG_VAR}"

PRODUCT_GIT_DNS_VAR="${PRODUCT_GIT_PROVIDER}_DNS"
PRODUCT_GIT_DNS="${!PRODUCT_GIT_DNS_VAR}"

PRODUCT_GIT_API_DNS_VAR="${PRODUCT_GIT_PROVIDER}_API_DNS"
PRODUCT_GIT_API_DNS="${!PRODUCT_GIT_API_DNS_VAR}"

# Determine the product local docker provider
if [[ -z "${PRODUCT_DOCKER_PROVIDER}" ]]; then
    PRODUCT_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_${SEGMENT_UPPER}_DOCKER_PROVIDER"
    if [[ -z "${!PRODUCT_DOCKER_PROVIDER_VAR}" ]]; then
        PRODUCT_DOCKER_PROVIDER_VAR="${PRODUCT_UPPER}_DOCKER_PROVIDER"
    fi
    PRODUCT_DOCKER_PROVIDER="${!PRODUCT_DOCKER_PROVIDER_VAR}"
    PRODUCT_DOCKER_PROVIDER="${PRODUCT_DOCKER_PROVIDER:-DOCKER}"
fi

PRODUCT_DOCKER_USER_VAR="${PRODUCT_DOCKER_PROVIDER}_USER"
PRODUCT_DOCKER_PASSWORD_VAR="${PRODUCT_DOCKER_PROVIDER}_PASSWORD"
PRODUCT_DOCKER_CREDENTIALS_VAR="${PRODUCT_DOCKER_PROVIDER}_CREDENTIALS"

PRODUCT_DOCKER_DNS_VAR="${PRODUCT_DOCKER_PROVIDER}_DNS"
PRODUCT_DOCKER_DNS="${!PRODUCT_DOCKER_DNS_VAR}"

PRODUCT_DOCKER_API_DNS_VAR="${PRODUCT_DOCKER_PROVIDER}_API_DNS"
PRODUCT_DOCKER_API_DNS="${!PRODUCT_DOCKER_API_DNS_VAR}"

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
PRODUCT_REMOTE_DOCKER_CREDENTIALS_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER}_CREDENTIALS"

PRODUCT_REMOTE_DOCKER_DNS_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER}_DNS"
PRODUCT_REMOTE_DOCKER_DNS="${!PRODUCT_REMOTE_DOCKER_DNS_VAR}"

PRODUCT_REMOTE_DOCKER_API_DNS_VAR="${PRODUCT_REMOTE_DOCKER_PROVIDER}_API_DNS"
PRODUCT_REMOTE_DOCKER_API_DNS="${!PRODUCT_REMOTE_DOCKER_API_DNS_VAR}"

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
PRODUCT_CODE_GIT_API_DNS="${!PRODUCT_CODE_GIT_API_DNS_VAR}"

# Determine code repo
if [[ -z "${PRODUCT_CODE_REPO}" ]]; then
    PRODUCT_CODE_REPO_VAR="${PRODUCT_UPPER}_${CODE_SLICE^^}_CODE_REPO"
    if [[ -z "${!PRODUCT_CODE_REPO_VAR}" ]]; then
        PRODUCT_CODE_REPO_VAR="${PRODUCT_UPPER}_CODE_REPO"
    fi
    PRODUCT_CODE_REPO="${!PRODUCT_CODE_REPO_VAR}"
fi

# Determine the deployment tag
if [[ -n "${DEPLOYMENT_NUMBER}" ]]; then
    DEPLOYMENT_TAG="d${DEPLOYMENT_NUMBER}-${SEGMENT}"
else
    DEPLOYMENT_TAG="d${BUILD_NUMBER}-${SEGMENT}"
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
echo "AID=${AID}" >> ${WORKSPACE}/context.properties
echo "PRODUCT=${PRODUCT}" >> ${WORKSPACE}/context.properties
if [[ -n "${SEGMENT}" ]]; then echo "SEGMENT=${SEGMENT}" >> ${WORKSPACE}/context.properties; fi
if [[ -n "${SLICE}" ]]; then echo "SLICE=${SLICE}" >> ${WORKSPACE}/context.properties; fi
if [[ -n "${SLICES}" ]]; then echo "SLICES=${SLICES}" >> ${WORKSPACE}/context.properties; fi
echo "SLICE_LIST=${SLICE_LIST}" >> ${WORKSPACE}/context.properties
echo "BUILD_SLICE=${BUILD_SLICE}" >> ${WORKSPACE}/context.properties

echo "GSGEN_GIT_DNS=${GSGEN_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "GSGEN_GIT_ORG=${GSGEN_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "GSGEN_BIN_REPO=${GSGEN_BIN_REPO}" >> ${WORKSPACE}/context.properties
echo "GSGEN_STARTUP_REPO=${GSGEN_STARTUP_REPO}" >> ${WORKSPACE}/context.properties

echo "AID_GIT_PROVIDER=${AID_GIT_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "AID_GIT_USER_VAR=${AID_GIT_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "AID_GIT_PASSWORD_VAR=${AID_GIT_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "AID_GIT_CREDENTIALS_VAR=${AID_GIT_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "AID_GIT_ORG=${AID_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "AID_GIT_DNS=${AID_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "AID_GIT_API_DNS=${AID_GIT_API_DNS}" >> ${WORKSPACE}/context.properties

echo "AID_AWS_ACCESS_KEY_ID_VAR=${AID_AWS_ACCESS_KEY_ID_VAR}" >> ${WORKSPACE}/context.properties
echo "AID_AWS_SECRET_ACCESS_KEY_VAR=${AID_AWS_SECRET_ACCESS_KEY_VAR}" >> ${WORKSPACE}/context.properties
echo "AID_TEMP_AWS_ACCESS_KEY_ID=${AID_TEMP_AWS_ACCESS_KEY_ID}" >> ${WORKSPACE}/context.properties
echo "AID_TEMP_AWS_SECRET_ACCESS_KEY=${AID_TEMP_AWS_SECRET_ACCESS_KEY}" >> ${WORKSPACE}/context.properties
echo "AID_TEMP_AWS_SESSION_TOKEN=${AID_TEMP_AWS_SESSION_TOKEN}" >> ${WORKSPACE}/context.properties

echo "AID_CONFIG_REPO=${AID_CONFIG_REPO}" >> ${WORKSPACE}/context.properties
echo "AID_INFRASTRUCTURE_REPO=${AID_INFRASTRUCTURE_REPO}" >> ${WORKSPACE}/context.properties

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
echo "PRODUCT_DOCKER_CREDENTIALS_VAR=${PRODUCT_DOCKER_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_DOCKER_DNS=${PRODUCT_DOCKER_DNS}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_DOCKER_API_DNS=${PRODUCT_DOCKER_API_DNS}" >> ${WORKSPACE}/context.properties

echo "PRODUCT_REMOTE_DOCKER_PROVIDER=${PRODUCT_REMOTE_DOCKER_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_REMOTE_DOCKER_USER_VAR=${PRODUCT_REMOTE_DOCKER_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_REMOTE_DOCKER_PASSWORD_VAR=${PRODUCT_REMOTE_DOCKER_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "PRODUCT_REMOTE_DOCKER_CREDENTIALS_VAR=${PRODUCT_REMOTE_DOCKER_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
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

echo "PRODUCT_CODE_REPO=${PRODUCT_CODE_REPO}" >> ${WORKSPACE}/context.properties

echo "GIT_USER=${GIT_USER}" >> ${WORKSPACE}/context.properties
echo "GIT_EMAIL=${GIT_EMAIL}" >> ${WORKSPACE}/context.properties
echo "DEPLOYMENT_TAG=${DEPLOYMENT_TAG}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# All good
RESULT=0

