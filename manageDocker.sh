#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

DOCKER_TAG_DEFAULT="latest"
DOCKER_IMAGE_SOURCE_DEFAULT="remote"
DOCKER_OPERATION_DEFAULT="verify"
function usage() {
    echo -e "\nManage docker images"
    echo -e "\nUsage: $(basename $0) -b -v -p -k -l DOCKER_REPO -t DOCKER_TAG -i REMOTE_DOCKER_REPO -r REMOTE_DOCKER_TAG -u DOCKER_IMAGE_SOURCE  -s DOCKER_SLICE -g DOCKER_CODE_COMMIT"
    echo -e "\nwhere\n"
    echo -e "(o) -b perform docker build and save in local registry"
    echo -e "(o) -g DOCKER_CODE_COMMIT to use when defaulting the local repository"
    echo -e "    -h shows this text"
    echo -e "(o) -i REMOTE_DOCKER_REPO is the repository to pull"
    echo -e "(o) -k tag an image in the local registry with the remote details"
    echo -e "(o) -l DOCKER_REPO is the local repository "
    echo -e "(o) -p pull image from a remote to a local registry"
    echo -e "(o) -r REMOTE_DOCKER_TAG is the tag to pull"
    echo -e "(o) -s DOCKER_SLICE is the slice to use when defaulting the local repository"
    echo -e "(o) -t DOCKER_TAG is the local tag"
    echo -e "(o) -u DOCKER_IMAGE_SOURCE is the registry to pull from"
    echo -e "(o) -v verify image is present in local registry"
    echo -e "\nDEFAULTS:\n"
    echo -e "DOCKER_REPO=\"\$PRODUCT/\$DOCKER_SLICE-\$DOCKER_CODE_COMMIT\" or "
    echo -e "\"\$PRODUCT/\$DOCKER_CODE_COMMIT\" if no build slice defined"
    echo -e "DOCKER_TAG=${DOCKER_TAG_DEFAULT}"
    echo -e "DOCKER_SLICE=\$BUILD_SLICE"
    echo -e "REMOTE_DOCKER_REPO=DOCKER_REPO"
    echo -e "REMOTE_DOCKER_TAG=DOCKER_TAG"
    echo -e "DOCKER_IMAGE_SOURCE=${DOCKER_IMAGE_SOURCE_DEFAULT}"
    echo -e "DOCKER_OPERATION=${DOCKER_OPERATION_DEFAULT}"
    echo -e "DOCKER_CODE_COMMIT=\"\$CODE_COMMIT\" or \"\$GIT_COMMIT\""
    echo -e "\nNOTES:\n"
    echo -e "1. DOCKER_IMAGE_SOURCE can be \"remote\" or \"dockerhub\""
    echo -e ""
    RESULT=1
    exit
}

# Determine if a docker registry is hosted by AWS
# $1 = registry
function isAWSRegistry() {
    if [[ "${1}" =~ ".amazonaws.com" ]]; then

        # Determine the registry account id and region
        AWS_REGISTRY_ID=$(echo "${1}" | cut -d '.' -f 1)
        AWS_REGISTRY_REGION=$(echo "${1}" | cut -d '.' -f 4)

        # Set up the AWS credentials
        CHECK_AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-${AID_TEMP_AWS_ACCESS_KEY_ID}}"
        CHECK_AWS_ACCESS_KEY_ID="${CHECK_AWS_ACCESS_KEY_ID:-${!AID_AWS_ACCESS_KEY_ID_VAR}}"
        if [[ -n "${CHECK_AWS_ACCESS_KEY_ID}" ]]; then export AWS_ACCESS_KEY_ID="${CHECK_AWS_ACCESS_KEY_ID}"; fi

        CHECK_AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-${AID_TEMP_AWS_SECRET_ACCESS_KEY}}"
        CHECK_AWS_SECRET_ACCESS_KEY="${CHECK_AWS_SECRET_ACCESS_KEY:-${!AID_AWS_SECRET_ACCESS_KEY_VAR}}"
        if [[ -n "${CHECK_AWS_SECRET_ACCESS_KEY}" ]]; then export AWS_SECRET_ACCESS_KEY="${CHECK_AWS_SECRET_ACCESS_KEY}"; fi

        CHECK_AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-${AID_TEMP_AWS_SESSION_TOKEN}}"
        CHECK_AWS_SESSION_TOKEN="${CHECK_AWS_SESSION_TOKEN:-${!AID_AWS_SESSION_TOKEN_VAR}}"
        if [[ -n "${CHECK_AWS_SESSION_TOKEN}" ]]; then export AWS_SESSION_TOKEN="${CHECK_AWS_SESSION_TOKEN}"; fi

        return 0
    else
        return 1
    fi
}

# Perform login logic required depending on the registry implementation
# $1 = registry
# $2 = user
# $3 = password
function dockerLogin() {
    isAWSRegistry $1
    if [[ $? -eq 0 ]]; then
        $(aws --region ${AWS_REGISTRY_REGION} ecr get-login --registry-ids ${AWS_REGISTRY_ID})
    else
        docker login -u ${2} -p ${3} ${1}
    fi
    return $?
}

# Perform logic required to create a repository depending on the registry implementation
# $1 = registry
# $2 = repository
function createRepository() {
    isAWSRegistry $1
    if [[ $? -eq 0 ]]; then
        aws --region ${AWS_REGISTRY_REGION} ecr describe-repositories --registry-id ${AWS_REGISTRY_ID} --repository-names "${2}" > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            # Not there yet so create it
            aws --region ${AWS_REGISTRY_REGION} ecr create-repository --repository-name "${2}"
            return $?
        fi
    fi
    return 0
}

# Parse options
while getopts ":bg:hki:l:pr:s:t:u:v" opt; do
    case $opt in
        b)
            DOCKER_OPERATION="build"
            ;;
        g)
            DOCKER_CODE_COMMIT="${OPTARG}"
            ;;
        h)
            usage
            ;;
        i)
            REMOTE_DOCKER_REPO="${OPTARG}"
            ;;
        k)
            DOCKER_OPERATION="tag"
            ;;
        l)
            DOCKER_REPO="${OPTARG}"
            ;;
        p)
            DOCKER_OPERATION="pull"
            ;;
        r)
            REMOTE_DOCKER_TAG="${OPTARG}"
            ;;
        s)
            DOCKER_SLICE="${OPTARG}"
            ;;
        t)
            DOCKER_TAG="${OPTARG}"
            ;;
        u)
            DOCKER_IMAGE_SOURCE="${OPTARG}"
            ;;
        v)
            DOCKER_OPERATION="verify"
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

# Apply local registry defaults
DOCKER_TAG="${DOCKER_TAG:-$DOCKER_TAG_DEFAULT}"
DOCKER_IMAGE_SOURCE="${DOCKER_IMAGE_SOURCE:-$DOCKER_IMAGE_SOURCE_DEFAULT}"
DOCKER_OPERATION="${DOCKER_OPERATION:-$DOCKER_OPERATION_DEFAULT}"
DOCKER_SLICE="${DOCKER_SLICE:-$BUILD_SLICE}"

# Default local repository is based on standard image naming conventions
DOCKER_CODE_COMMIT="${DOCKER_CODE_COMMIT:-$CODE_COMMIT}"
DOCKER_CODE_COMMIT="${DOCKER_CODE_COMMIT:-$GIT_COMMIT}"
if [[ -z "${DOCKER_REPO}" ]]; then
    if [[ (-z "${DOCKER_SLICE}" ) || ( -n "${DOCKER_INHIBIT_SLICE_IN_REPO}" ) ]]; then
        DOCKER_REPO="${PRODUCT}/${DOCKER_CODE_COMMIT}"
    else
        DOCKER_REPO="${PRODUCT}/${DOCKER_SLICE}-${DOCKER_CODE_COMMIT}"
    fi
fi

# Ensure the local repository has been determined
if [[ -z "${DOCKER_REPO}" ]]; then
	echo "Job requires the local repository name"
    usage
fi

# Apply remote registry defaults
REMOTE_DOCKER_REPO="${REMOTE_DOCKER_REPO:-$DOCKER_REPO}"
REMOTE_DOCKER_TAG="${REMOTE_DOCKER_TAG:-$DOCKER_TAG}"

# Formulate the local registry details
DOCKER_IMAGE="${DOCKER_REPO}:${DOCKER_TAG}"
FULL_DOCKER_IMAGE="${PRODUCT_DOCKER_DNS}/${DOCKER_IMAGE}"

# Confirm access to the local registry
dockerLogin ${PRODUCT_DOCKER_DNS} ${!PRODUCT_DOCKER_USER_VAR} ${!PRODUCT_DOCKER_PASSWORD_VAR} 
RESULT=$?
if [[ "$RESULT" -ne 0 ]]; then
   echo "Can't log in to ${PRODUCT_DOCKER_DNS}"
   exit
fi

# Perform the required action
case ${DOCKER_OPERATION} in
    build)
        docker build -t "${FULL_DOCKER_IMAGE}" .
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo "Cannot build image ${DOCKER_IMAGE}"
            exit
        fi
        createRepository ${PRODUCT_DOCKER_DNS} ${DOCKER_REPO}
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo "Unable to create repository ${DOCKER_REPO} in the local registry"
        fi
        docker push ${FULL_DOCKER_IMAGE}
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo "Unable to push ${DOCKER_IMAGE} to the local registry"
        fi
        ;;

    verify)
        # Check whether the image is already in the local registry
        # Use the docker API to avoid having to download the image to verify its existence
        isAWSRegistry ${PRODUCT_DOCKER_DNS}
        if [[ $? -eq 0 ]]; then
            DOCKER_IMAGE_PRESENT=$(aws --region ${AWS_REGISTRY_REGION} ecr list-images --registry-id ${AWS_REGISTRY_ID} --repository-name "${DOCKER_REPO}" | jq ".imageIds[] | select(.imageTag==\"${DOCKER_TAG}\") | select(.!=null)")
        else
            # Be careful of @ characters in the username or password
            DOCKER_USER=$(echo ${!PRODUCT_DOCKER_USER_VAR} | sed "s/@/%40/g")
            DOCKER_PASSWORD=$(echo ${!PRODUCT_DOCKER_PASSWORD_VAR} | sed "s/@/%40/g")
            DOCKER_IMAGE_PRESENT=$(curl -s https://${DOCKER_USER}:${DOCKER_PASSWORD}@${PRODUCT_DOCKER_API_DNS}/v1/repositories/${DOCKER_REPO}/tags | jq ".[\"${DOCKER_TAG}\"] | select(.!=null)")
        fi

        if [[ -n "${DOCKER_IMAGE_PRESENT}" ]]; then
            echo "Image ${DOCKER_IMAGE} present in the local registry"
            RESULT=0
        else
            echo "Image ${DOCKER_IMAGE} not present in the local registry"
            RESULT=1
        fi
        ;;

    tag)
        # Formulate the tag details
        REMOTE_DOCKER_IMAGE="${REMOTE_DOCKER_REPO}:${REMOTE_DOCKER_TAG}"
        FULL_REMOTE_DOCKER_IMAGE="${PRODUCT_DOCKER_DNS}/${REMOTE_DOCKER_IMAGE}"

        # Pull in the local image
        docker pull ${FULL_DOCKER_IMAGE}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo "Can't pull ${DOCKER_IMAGE} from ${PRODUCT_DOCKER_DNS}"
        else
            # Tag the image ready to push to the registry
            docker tag ${FULL_DOCKER_IMAGE} ${FULL_REMOTE_DOCKER_IMAGE}
            RESULT=$?
            if [[ "$?" -ne 0 ]]; then
                echo "Couldn't tag image ${FULL_DOCKER_IMAGE} with ${FULL_REMOTE_DOCKER_IMAGE}"
            else
                # Push to registry
                createRepository ${PRODUCT_DOCKER_DNS} ${REMOTE_DOCKER_REPO}
                RESULT=$?
                if [ $RESULT -ne 0 ]; then
                    echo "Unable to create repository ${REMOTE_DOCKER_REPO} in the local registry"
                fi

                docker push ${FULL_REMOTE_DOCKER_IMAGE}
                RESULT=$?
                if [[ "$?" -ne 0 ]]; then
                    echo "Unable to push ${REMOTE_DOCKER_IMAGE} to the local registry"
                fi
            fi
        fi
        ;;        

    pull)
        # Formulate the remote registry details
        REMOTE_DOCKER_IMAGE="${REMOTE_DOCKER_REPO}:${REMOTE_DOCKER_TAG}"

        case ${DOCKER_IMAGE_SOURCE} in
            remote)
                FULL_REMOTE_DOCKER_IMAGE="${PRODUCT_REMOTE_DOCKER_DNS}/${REMOTE_DOCKER_IMAGE}"

                # Confirm access to the remote registry
                dockerLogin ${PRODUCT_REMOTE_DOCKER_DNS} ${!PRODUCT_REMOTE_DOCKER_USER_VAR} ${!PRODUCT_REMOTE_DOCKER_PASSWORD_VAR}
                RESULT=$?
                if [[ "$RESULT" -ne 0 ]]; then
                    echo "Can't log in to ${PRODUCT_REMOTE_DOCKER_DNS}"
                    exit
                fi
                ;;
                
            *)
                FULL_REMOTE_DOCKER_IMAGE="${REMOTE_DOCKER_IMAGE}"
                ;;
        esac

        # Pull in the remote image
        docker pull ${FULL_REMOTE_DOCKER_IMAGE}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo "Can't pull ${REMOTE_DOCKER_IMAGE} from ${DOCKER_IMAGE_SOURCE}"
        else
            # Tag the image ready to push to the registry
            docker tag ${FULL_REMOTE_DOCKER_IMAGE} ${FULL_DOCKER_IMAGE}
            RESULT=$?
            if [[ "$?" -ne 0 ]]; then
                echo "Couldn't tag image ${FULL_REMOTE_DOCKER_IMAGE} with ${FULL_DOCKER_IMAGE}"
            else
                # Push to registry
                createRepository ${PRODUCT_DOCKER_DNS} ${DOCKER_REPO}
                RESULT=$?
                if [ $RESULT -ne 0 ]; then
                    echo "Unable to create repository ${DOCKER_REPO} in the local registry"
                else
                    docker push ${FULL_DOCKER_IMAGE}
                    RESULT=$?
                    if [[ "$?" -ne 0 ]]; then
                        echo "Unable to push ${DOCKER_IMAGE} to the local registry"
                    fi
                fi
            fi
        fi
        ;;        
        
    *)
        # For any other value, use the docker command default = dockerhub
        echo -e "\n Unknown operation \"${DOCKER_OPERATION}\""
        usage
        ;;
esac

IMAGEID=$(docker images | grep "${REMOTE_DOCKER_REPO}" | grep "${REMOTE_DOCKER_TAG}" | head -1 |awk '{print($3)}')
if [[ "${IMAGEID}" != "" ]]; then
    docker rmi -f ${IMAGEID}
fi

IMAGEID=$(docker images | grep "${DOCKER_REPO}" | grep "${DOCKER_TAG}" | head -1 |awk '{print($3)}')
if [[ "${IMAGEID}" != "" ]]; then
    docker rmi -f ${IMAGEID}
fi

