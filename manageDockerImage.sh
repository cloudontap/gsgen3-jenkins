#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

REMOTE_TAG_DEFAULT="latest"
IMAGE_SOURCE_DEFAULT="remote"
function usage() {
    echo -e "\nManage docker images"
    echo -e "\nUsage: $(basename $0) -c -i REMOTE_IMAGE -l LOCAL_IMAGE -r REMOTE_TAG -s IMAGE_SOURCE -t LOCAL_TAG"
    echo -e "\nwhere\n"
    echo -e "(o) -c only check if image present, don't try and pull it if not"
    echo -e "    -h shows this text"
    echo -e "(o) -i REMOTE_IMAGE to use when pulling in the image"
    echo -e "(o) -l LOCAL_IMAGE to use when saving image in the registry"
    echo -e "(o) -r REMOTE_TAG to use when pulling in the image"
    echo -e "(o) -s IMAGE_SOURCE is the location to pull from"
    echo -e "(o) -t LOCAL_TAG to use when saving image in the registry"
    echo -e "\nDEFAULTS:\n"
    echo -e "REMOTE_TAG=${REMOTE_TAG_DEFAULT}"
    echo -e "LOCAL_IMAGE=REMOTE_IMAGE"
    echo -e "LOCAL_TAG=REMOTE_TAG"
    echo -e "IMAGE_SOURCE=${IMAGE_SOURCE_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e "1) Default behaviour is to pull from the remote registry"
    echo -e "2) If not provided, REMOTE_* values are used for LOCAL_*"
    echo -e ""
    exit
}

PULL_IF_ABSENT="true"
# Parse options
while getopts ":chr:t:" opt; do
    case $opt in
        c)
            PULL_IF_ABSENT="false"
            ;;
        h)
            usage
            ;;
        i)
            REMOTE_IMAGE="${OPTARG}"
            ;;
        l)
            LOCAL_IMAGE="${OPTARG}"
            ;;
        r)
            REMOTE_TAG="${OPTARG}"
            ;;
        t)
            LOCAL_TAG="${OPTARG}"
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
if [[ "${REMOTE_IMAGE}" == "" ]]; then
	echo "Job requires the remote image name"
    RESULT=1
    exit
fi

# Apply defaults
if [[ "${REMOTE_TAG}" == "" ]]; then
    REMOTE_TAG="${REMOTE_TAG_DEFAULT}"
fi
if [[ "${IMAGE_SOURCE}" == "" ]]; then
    IMAGE_SOURCE="${IMAGE_SOURCE_DEFAULT}"
fi

# Confirm local image settings
if [[ "${LOCAL_IMAGE}" == "" ]]; then
    LOCAL_IMAGE="${REMOTE_IMAGE}"
fi
if [[ "${LOCAL_TAG}" == "" ]]; then
    LOCAL_TAG="${REMOTE_TAG}"
fi

# Formulate the remote image details
REMOTE_REGISTRY_IMAGE="${REMOTE_IMAGE}:${REMOTE_TAG}"
FULL_REMOTE_REGISTRY_IMAGE="${REMOTE_REGISTRY_IMAGE}"
if [[ "${SOURCE}" == "remote" ]]; then
    FULL_REMOTE_REGISTRY_IMAGE="${REMOTE_DOCKER_REGISTRY}/${REMOTE_REGISTRY_IMAGE}"
    sudo docker login -u ${REMOTE_DOCKER_USER} -p ${REMOTE_DOCKER_PASS} -e ${REMOTE_DOCKER_EMAIL} ${REMOTE_DOCKER_REGISTRY}
    RESULT=$?
    if [[ "$RESULT" -ne 0 ]]; then  
	    echo "Can't log in to ${REMOTE_DOCKER_REGISTRY}"
        exit
    fi
fi

# Formulate the local image details
LOCAL_REGISTRY_IMAGE="${LOCAL_IMAGE}:${LOCAL_TAG}"
FULL_LOCAL_REGISTRY_IMAGE="${DOCKER_REGISTRY}/${LOCAL_REGISTRY_IMAGE}"

# Check if image has already been pulled
sudo docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} -e ${DOCKER_EMAIL} ${DOCKER_REGISTRY}
RESULT=$?
if [[ "$RESULT" -ne 0 ]]; then  
   echo "Can't log in to ${DOCKER_REGISTRY}"
   exit
fi
sudo docker pull ${FULL_LOCAL_REGISTRY_IMAGE}
RESULT=$?
if [[ "$RESULT" -eq 0 ]]; then  
	echo "Image ${LOCAL_REGISTRY_IMAGE} present in the registry."
else
    if [[ "${PULL_IF_ABSENT}" == "true" ]]; then
        sudo docker pull ${FULL_REMOTE_REGISTRY_IMAGE}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo "Pull of ${REMOTE_REGISTRY_IMAGE} from ${REMOTE_DOCKER_REGISTRY} failed"
        else
            # Tag the image ready to push to the registry
            sudo docker tag ${FULL_REMOTE_REGISTRY_IMAGE} ${FULL_LOCAL_REGISTRY_IMAGE}

            # Push to registry
            sudo docker push ${FULL_LOCAL_REGISTRY_IMAGE}
            RESULT=$?
            if [[ "$?" -ne 0 ]]; then
                echo "Couldn't push image ${LOCAL_REGISTRY_IMAGE} to ${FULL_LOCAL_REGISTRY_IMAGE}"
            fi
        fi
    fi
fi

if [[ "${PULL_IF_ABSENT}" == "true" ]]; then
    IMAGEID=$(sudo docker images | grep "${REMOTE_IMAGE}" | grep "${REMOTE_TAG}" | head -1 |awk '{print($3)}')
    if [[ "${IMAGEID}" != "" ]]; then
        sudo docker rmi -f ${IMAGEID}
    fi
fi
IMAGEID=$(sudo docker images | grep "${LOCAL_IMAGE}" | grep "${LOCAL_TAG}" | head -1 |awk '{print($3)}')
if [[ "${IMAGEID}" != "" ]]; then
    sudo docker rmi -f ${IMAGEID}
fi

