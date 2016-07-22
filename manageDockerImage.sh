#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

REMOTE_DOCKER_TAG_DEFAULT="latest"
DOCKER_IMAGE_SOURCE_DEFAULT="local"
function usage() {
    echo -e "\nManage docker images"
    echo -e "\nUsage: $(basename $0) -c -i REMOTE_DOCKER_REPO -l DOCKER_REPO -r REMOTE_DOCKER_TAG -s DOCKER_IMAGE_SOURCE -t DOCKER_TAG"
    echo -e "\nwhere\n"
    echo -e "(o) -c only check if image present, don't try and pull it if not"
    echo -e "    -h shows this text"
    echo -e "(m) -i REMOTE_DOCKER_REPO to use when pulling in the image"
    echo -e "(o) -l DOCKER_REPO to use when saving image"
    echo -e "(o) -r REMOTE_DOCKER_TAG to use when pulling in the image"
    echo -e "(o) -s DOCKER_IMAGE_SOURCE is the location to pull from"
    echo -e "(o) -t DOCKER_TAG to use when saving image"
    echo -e "\nDEFAULTS:\n"
    echo -e "REMOTE_DOCKER_TAG=${REMOTE_DOCKER_TAG_DEFAULT}"
    echo -e "DOCKER_REPO=REMOTE_DOCKER_REPO"
    echo -e "DOCKER_TAG=REMOTE_DOCKER_TAG"
    echo -e "DOCKER_IMAGE_SOURCE=${DOCKER_IMAGE_SOURCE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1) Default behaviour is to pull from the remote registry"
    echo -e "2) If not explicitly provided on the command line, REMOTE_DOCKER_REPO"
    echo -e "   MUST already be set in the environment"
    echo -e "3) DOCKER_IMAGE_SOURCE can be \"remote\", \"local\" or \"dockerhub\""
    echo -e ""
    exit
}

PULL_IF_ABSENT="true"
# Parse options
while getopts ":chi:l:r:s:t:" opt; do
    case $opt in
        c)
            PULL_IF_ABSENT="false"
            ;;
        h)
            usage
            ;;
        i)
            REMOTE_DOCKER_REPO="${OPTARG}"
            ;;
        l)
            DOCKER_REPO="${OPTARG}"
            ;;
        r)
            REMOTE_DOCKER_TAG="${OPTARG}"
            ;;
        s)
            DOCKER_IMAGE_SOURCE="${OPTARG}"
            ;;
        t)
            DOCKER_TAG="${OPTARG}"
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

# Ensure the IMAGE has been provided
if [[ -z "${REMOTE_DOCKER_REPO}" ]]; then
	echo "Job requires the remote repository name"
    exit
fi

# Apply defaults
REMOTE_DOCKER_TAG="${REMOTE_DOCKER_TAG:-$REMOTE_DOCKER_TAG_DEFAULT}"
DOCKER_IMAGE_SOURCE="${DOCKER_IMAGE_SOURCE:-$DOCKER_IMAGE_SOURCE_DEFAULT}"

# Confirm local image settings
DOCKER_REPO="${DOCKER_REPO:-$REMOTE_DOCKER_REPO}"
DOCKER_TAG="${DOCKER_TAG:-$REMOTE_DOCKER_TAG}"

# Formulate the remote image details
REMOTE_REPOSITORY="${REMOTE_DOCKER_REPO}:${REMOTE_DOCKER_TAG}"
FULL_REMOTE_REPOSITORY="${REMOTE_REPOSITORY}"
case ${DOCKER_IMAGE_SOURCE} in
    remote)
        FULL_REMOTE_REPOSITORY="${PROJECT_REMOTE_DOCKER_DNS}/${REMOTE_REPOSITORY}"
        sudo docker login -u ${!PROJECT_REMOTE_DOCKER_USER_VAR} -p ${!PROJECT_REMOTE_DOCKER_PASSWORD_VAR} -e ${PROJECT_REMOTE_DOCKER_EMAIL} ${PROJECT_REMOTE_DOCKER_DNS}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo "Can't log in to ${PROJECT_REMOTE_DOCKER_DNS}"
            exit
        fi
        ;;
    local)
        FULL_REMOTE_REPOSITORY="${PROJECT_DOCKER_DNS}/${REMOTE_REPOSITORY}"
        ;;
    *)
        # For any other value, use the docker command default = dockerhub
        ;;
esac

# Formulate the local image details
REPOSITORY="${DOCKER_REPO}:${DOCKER_TAG}"
FULL_REPOSITORY="${PROJECT_DOCKER_DNS}/${REPOSITORY}"

# Check if image has already been pulled
sudo docker login -u ${!PROJECT_DOCKER_USER_VAR} -p ${!PROJECT_REMOTE_DOCKER_PASSWORD_VAR} -e ${PROJECT_REMOTE_DOCKER_EMAIL} ${PROJECT_DOCKER_DNS}
RESULT=$?
if [[ "$RESULT" -ne 0 ]]; then
   echo "Can't log in to ${PROJECT_DOCKER_DNS}"
   exit
fi

# Use the docker API to avoid having to download the image to check for its existence
# Be careful of @ characters in the username or password
DOCKER_USER=$(echo ${!PROJECT_DOCKER_USER_VAR} | sed "s/@/%40/g")
DOCKER_PASSWORD=$(echo ${!PROJECT_DOCKER_PASSWORD_VAR} | sed "s/@/%40/g")
DOCKER_IMAGE_COMMIT=$(curl -s https://${DOCKER_USER}:${DOCKER_PASSWORD}@${PROJECT_DOCKER_API_DNS}/v1/repositories/${DOCKER_REPO}/tags | jq ".[\"${DOCKER_TAG}\"] | select(.!=null)")
if [[ -n "${DOCKER_IMAGE_COMMIT}" ]]; then
	echo "Image ${REPOSITORY} present in the registry."
else
    if [[ "${PULL_IF_ABSENT}" == "true" ]]; then
        sudo docker pull ${FULL_REMOTE_REPOSITORY}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo "Can't pull ${REMOTE_REPOSITORY} from ${PROJECT_REMOTE_DOCKER_DNS}"
        else
            # Tag the image ready to push to the registry
            sudo docker tag ${FULL_REMOTE_REPOSITORY} ${FULL_REPOSITORY}

            # Push to registry
            sudo docker push ${FULL_REPOSITORY}
            RESULT=$?
            if [[ "$?" -ne 0 ]]; then
                echo "Couldn't push image ${REPOSITORY} to ${FULL_REPOSITORY}"
            fi
        fi
    else
        # Image not present
        RESULT=1
    fi
fi

if [[ "${PULL_IF_ABSENT}" == "true" ]]; then
    IMAGEID=$(sudo docker images | grep "${REMOTE_DOCKER_REPO}" | grep "${REMOTE_DOCKER_TAG}" | head -1 |awk '{print($3)}')
    if [[ "${IMAGEID}" != "" ]]; then
        sudo docker rmi -f ${IMAGEID}
    fi
fi
IMAGEID=$(sudo docker images | grep "${DOCKER_REPO}" | grep "${DOCKER_TAG}" | head -1 |awk '{print($3)}')
if [[ "${IMAGEID}" != "" ]]; then
    sudo docker rmi -f ${IMAGEID}
fi

