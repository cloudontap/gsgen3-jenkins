#!/bin/bash

if [[ -n "${AUTOMATION_DEBUG}" ]]; then set ${AUTOMATION_DEBUG}; fi
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

DEPLOY_RELEASE_DEFAULT="false"
function usage() {
    echo -e "\nDeploy one or more slices"
    echo -e "\nUsage: $(basename $0) -r"
    echo -e "\nwhere\n"
    echo -e "    -h shows this text"
    echo -e "(o) -r if deploying a release"
    echo -e "\nDEFAULTS:\n"
    echo -e "DEPLOY_RELEASE = ${DEPLOY_RELEASE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1. If deploying a release, the release and deployment are"
    echo -e "   included in the DETAIL_MESSAGE, and the cloud formation"
    echo -e "   templates are regenerated"
    echo -e ""
    RESULT=1
    exit
}

# Parse options
while getopts ":hr" opt; do
    case $opt in
        h)
            usage
            ;;
        r)
            DEPLOY_RELEASE="true"
            ;;
        \?)
            echo -e "\nInvalid option: -${OPTARG}"
            usage
            ;;
        :)
            echo -e "\nOption -${OPTARG} requires an argument"
            usage
            ;;
     esac
done

# Apply defaults
DEPLOY_RELEASE="${DEPLOY_RELEASE:-${DEPLOY_RELEASE_DEFAULT}}"

if [[ "${DEPLOY_RELEASE}" == "true" ]]; then
    # Add release tag and deployment to details
    DETAIL_MESSAGE="deployment=d${BUILD_NUMBER}-${SEGMENT}, release=${RELEASE_TAG}, ${DETAIL_MESSAGE}"
    echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties
fi

cd ${WORKSPACE}/${ACCOUNT}/config/${PRODUCT}/solutions/${SEGMENT}

for CURRENT_SLICE in ${SLICE_LIST}; do

    if [[ "${DEPLOY_RELEASE}" != "true" ]]; then
        # Generate the deployment template for the required slice
        ${GENERATION_DIR}/createApplicationTemplate.sh -c ${PRODUCT_CONFIG_COMMIT} -s ${CURRENT_SLICE}
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo -e "\nTemplate build for ${CURRENT_SLICE} slice failed"
            exit
        fi
    fi

    if [[ "${MODE}" != "update" ]]; then ${GENERATION_DIR}/manageStack.sh -t application -s ${CURRENT_SLICE} -d; fi
    if [[ "${MODE}" != "stop"   ]]; then ${GENERATION_DIR}/manageStack.sh -t application -s ${CURRENT_SLICE}; fi
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo -e "\nStack deployment for ${CURRENT_SLICE} slice failed"
        exit
    fi
done

# All good
RESULT=0

