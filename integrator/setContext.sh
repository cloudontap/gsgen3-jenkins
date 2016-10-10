#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

CID_DEFAULT="gs04"
function usage() {
    echo -e "\nDetermine key settings for an integrator" 
    echo -e "\nUsage: $(basename $0) -c CID -t TID -a AID"
    echo -e "\nwhere\n"
    echo -e "(o) -a AID is the tenant account id e.g. \"env01\""
    echo -e "(o) -c CID is the integrator cyber account id"
    echo -e "    -h shows this text"
    echo -e "(o) -t TID is the tenant id e.g. \"env\""
    echo -e "\nDEFAULTS:\n"
    echo -e "CID=${CID_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1. The setting values are saved in context.properties in the current directory"
    echo -e ""
    exit
}

# Parse options
while getopts ":a:c:ht:" opt; do
    case $opt in
        a)
            AID="${OPTARG}"
            ;;
        c)
            CID="${OPTARG}"
            ;;
        h)
            usage
            ;;
        t)
            TID="${OPTARG}"
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
CID=${CID:-$CID_DEFAULT}

# Determine the tenant/account from the job name
# if not already defined or provided on the command line
JOB_PATH=($(echo "${JOB_NAME}" | tr "/" " "))
if [[ "${#JOB_PATH[@]}" -gt 2 ]]; then
    TID=${TID:-${JOB_PATH[0]}}
    AID=${AID:-${JOB_PATH[1]}}
else
    if [[ "${#JOB_PATH[@]}" -gt 1 ]]; then
        TID=${TID:-${JOB_PATH[0]}}
    else
        TID=${TID:-$(echo ${JOB_NAME} | cut -d '-' -f 1)}
    fi
fi

CID=${CID,,}
CID_UPPER=${CID^^}

TID=${TID,,}
TID_UPPER=${TID^^}

AID=${AID,,}
AID_UPPER=${AID^^}

# Default "GITHUB" git provider
GITHUB_DNS="${GITHUB_DNS:-github.com}"
GITHUB_API_DNS="${GITHUB_API_DNS:-api.$GITHUB_DNS}"

# Defaults for gsgen
GSGEN_GIT_DNS="${GSGEN_GIT_DNS:-github.com}"
GSGEN_GIT_ORG="${GSGEN_GIT_ORG:-codeontap}"
GSGEN_BIN_REPO="${GSGEN_BIN_REPO:-gsgen3.git}"

# Determine the cyber account access credentials
CID_AWS_ACCESS_KEY_ID_VAR="${CID_UPPER}_AWS_ACCESS_KEY_ID"
CID_AWS_SECRET_ACCESS_KEY_VAR="${CID_UPPER}_AWS_SECRET_ACCESS_KEY"

# Determine the cyber account git provider
if [[ -z "${CID_GIT_PROVIDER}" ]]; then
    CID_GIT_PROVIDER_VAR="${CID_UPPER}_GIT_PROVIDER"
    CID_GIT_PROVIDER="${!CID_GIT_PROVIDER_VAR}"
    CID_GIT_PROVIDER="${CID_GIT_PROVIDER:-GITHUB}"
fi

CID_GIT_USER_VAR="${CID_GIT_PROVIDER}_USER"
CID_GIT_PASSWORD_VAR="${CID_GIT_PROVIDER}_PASSWORD"
CID_GIT_CREDENTIALS_VAR="${CID_GIT_PROVIDER}_CREDENTIALS"

CID_GIT_ORG_VAR="${CID_GIT_PROVIDER}_ORG"
CID_GIT_ORG="${!CID_GIT_ORG_VAR}"

CID_GIT_DNS_VAR="${CID_GIT_PROVIDER}_DNS"
CID_GIT_DNS="${!CID_GIT_DNS_VAR}"

CID_GIT_API_DNS_VAR="${CID_GIT_PROVIDER}_API_DNS"
CID_GIT_API_DNS="${!CID_GIT_API_DNS_VAR}"

# Determine cyber account repo
if [[ -z "${CID_REPO}" ]]; then
    CID_REPO_VAR="${CID_UPPER}_REPO"
    CID_REPO="${!CID_REPO_VAR}"
fi

# Determine who to include as the author if git updates required
GIT_USER="${GIT_USER:-$BUILD_USER}"
GIT_USER="${GIT_USER:-$GIT_USER_DEFAULT}"
GIT_EMAIL="${GIT_EMAIL:-$BUILD_USER_EMAIL}"
GIT_EMAIL="${GIT_EMAIL:-$GIT_EMAIL_DEFAULT}"

# Basic details for git commits/slack notification (enhanced by other scripts)
DETAIL_MESSAGE="tenant=${TID}"
if [[ -n "${AID}" ]]; then DETAIL_MESSAGE="${DETAIL_MESSAGE}, account=${AID}"; fi
if [[ -n "${GIT_USER}" ]];  then DETAIL_MESSAGE="${DETAIL_MESSAGE}, user=${GIT_USER}"; fi

# Save for future steps
echo "CID=${CID}" >> ${WORKSPACE}/context.properties
echo "TID=${TID}" >> ${WORKSPACE}/context.properties
echo "AID=${AID}" >> ${WORKSPACE}/context.properties

echo "GSGEN_GIT_DNS=${GSGEN_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "GSGEN_GIT_ORG=${GSGEN_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "GSGEN_BIN_REPO=${GSGEN_BIN_REPO}" >> ${WORKSPACE}/context.properties

echo "CID_GIT_PROVIDER=${CID_GIT_PROVIDER}" >> ${WORKSPACE}/context.properties
echo "CID_GIT_USER_VAR=${CID_GIT_USER_VAR}" >> ${WORKSPACE}/context.properties
echo "CID_GIT_PASSWORD_VAR=${CID_GIT_PASSWORD_VAR}" >> ${WORKSPACE}/context.properties
echo "CID_GIT_CREDENTIALS_VAR=${CID_GIT_CREDENTIALS_VAR}" >> ${WORKSPACE}/context.properties
echo "CID_GIT_ORG=${CID_GIT_ORG}" >> ${WORKSPACE}/context.properties
echo "CID_GIT_DNS=${CID_GIT_DNS}" >> ${WORKSPACE}/context.properties
echo "CID_GIT_API_DNS=${CID_GIT_API_DNS}" >> ${WORKSPACE}/context.properties

echo "CID_AWS_ACCESS_KEY_ID_VAR=${CID_AWS_ACCESS_KEY_ID_VAR}" >> ${WORKSPACE}/context.properties
echo "CID_AWS_SECRET_ACCESS_KEY_VAR=${CID_AWS_SECRET_ACCESS_KEY_VAR}" >> ${WORKSPACE}/context.properties

echo "CID_REPO=${CID_REPO}" >> ${WORKSPACE}/context.properties

echo "GIT_USER=${GIT_USER}" >> ${WORKSPACE}/context.properties
echo "GIT_EMAIL=${GIT_EMAIL}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# All good
RESULT=0

