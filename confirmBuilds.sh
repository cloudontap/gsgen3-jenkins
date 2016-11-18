#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi
JENKINS_DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )
trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

# Prepare access to build info 
SLICE_ARRAY=(${SLICE_LIST})
CODE_TAG_ARRAY=(${CODE_TAG_LIST})
CODE_REPO_ARRAY=(${CODE_REPO_LIST})
CODE_COMMIT_ARRAY=()

# Loop through the slices and check each code tag
for INDEX in $(seq 0 ${#SLICE_ARRAY[@]}); do

    # Ensure code repo defined if tag provided
    if [[ (-n "${CODE_TAG_ARRAY[$INDEX]}")]]; then
        if [[ (-z "${CODE_REPO_ARRAY[$INDEX]}") ]]; then
            echo -e "\nNo code repo defined for slice ${SLICE_ARRAY[$INDEX]}"
            exit
        fi
    else
        if [[ (-n "${CODE_REPO_ARRAY[$INDEX]}") ]]; then
            echo -e "\nSlice ${SLICE_ARRAY[$INDEX]} requires a code tag"
            exit
        else
            # Nothing to do for this slice - no tag or repo
            CODE_COMMIT_ARRAY+=("\"\"")
            continue
        fi
    fi
    
    # Get the commit corresponding to the tag
    TAG_COMMIT=$(git ls-remote -t https://${!PRODUCT_CODE_GIT_CREDENTIALS_VAR}@${PRODUCT_CODE_GIT_DNS}/${PRODUCT_CODE_GIT_ORG}/${CODE_REPO_ARRAY[$INDEX]} \
                    "${CODE_TAG_ARRAY[$INDEX]}" | cut -f 1)
    CODE_COMMIT=$(git ls-remote -t https://${!PRODUCT_CODE_GIT_CREDENTIALS_VAR}@${PRODUCT_CODE_GIT_DNS}/${PRODUCT_CODE_GIT_ORG}/${CODE_REPO_ARRAY[$INDEX]} \
                    "${CODE_TAG_ARRAY[$INDEX]}^{}" | cut -f 1)
    if [[ -z "${CODE_COMMIT}" ]]; then
        echo -e "\nTag ${CODE_TAG_ARRAY[$INDEX]} not found in the ${CODE_REPO_ARRAY[$INDEX]} repo"
        exit
    fi
    
    # Fetch other info about the tag
    # We are using a github api here to avoid having to pull in the whole repo - 
    # git currently doesn't have a command to query the message of a remote tag
    CODE_COMMIT_SHORT="${CODE_COMMIT:0:8}"
    CODE_TAG_MESSAGE=$(curl -s https://${!PRODUCT_CODE_GIT_CREDENTIALS_VAR}@${PRODUCT_CODE_GIT_API_DNS}/repos/${PRODUCT_CODE_GIT_ORG}/${CODE_REPO_ARRAY[$INDEX]}/git/tags/${TAG_COMMIT} | jq .message | tr -d '"')
    if [[ (-z "${CODE_TAG_MESSAGE}") || ("${CODE_TAG_MESSAGE}" == "Not Found") ]]; then
        echo -e "\nMessage for tag ${CODE_TAG_ARRAY[$INDEX]} not found in the ${CODE_REPO_ARRAY[$INDEX]} repo"
        exit
    fi

    # Confirm the commit built successfully into a docker image
    ${JENKINS_DIR}/manageDocker.sh -v -s ${SLICE_ARRAY[$INDEX]} -g "${CODE_COMMIT}"
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo -e "\nDocker image for slice ${SLICE_ARRAY[$INDEX]} and commit ${CODE_COMMIT_SHORT} not found. Was the build successful?"
        exit
    fi

    # Save details of this slice
    CODE_COMMIT_ARRAY+=("${CODE_COMMIT}")
    DETAIL_MESSAGE="${DETAIL_MESSAGE}, ${SLICE_ARRAY[$INDEX]}=${CODE_TAG_ARRAY[$INDEX]} (${CODE_COMMIT_SHORT})"

done

# Save for future steps
echo "CODE_COMMIT_LIST=${CODE_COMMIT_ARRAY[@]}" >> ${WORKSPACE}/context.properties
echo "DETAIL_MESSAGE=${DETAIL_MESSAGE}" >> ${WORKSPACE}/context.properties

# All good
RESULT=0
