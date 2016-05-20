#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

function usage() {
    echo -e "\nManage docker images"
    echo -e "\nUsage: $(basename $0) -c"
    echo -e "\nwhere\n"
    echo -e "(o) -c only check if image present, don't try and pull it if not"
    echo -e "    -h shows this text"
    echo -e "\nNOTES:\n"
    echo -e "1) Default behaviour is to pull from the remote registry"
    echo -e ""
    exit
}

PULL_IF_ABSENT="true"
# Parse options
while getopts ":ch" opt; do
    case $opt in
        c)
            PULL_IF_ABSENT="false"
            ;;
        h)
            usage
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
if [[ "${IMAGE}" == "" ]]; then
	echo "Job requires the image name"
    RESULT=1
    exit
fi

# Generate the docker image identifiers
IMAGE_TAG="${IMAGE_TAG:-latest}"
if [[ "${LOCAL_IMAGE}" == "" ]]; then
    LOCAL_IMAGE="${IMAGE}"
fi

# Formulate the remote image details
REMOTE_IMAGE="${IMAGE}:${IMAGE_TAG}"
FULL_REMOTE_IMAGE="${REMOTE_IMAGE}"
if [[ "${SOURCE}" == "remote" ]]; then
    FULL_REMOTE_IMAGE="${REMOTE_DOCKER_REGISTRY}/${REMOTE_IMAGE}"
    sudo docker login -u ${REMOTE_DOCKER_USER} -p ${REMOTE_DOCKER_PASS} -e ${REMOTE_DOCKER_EMAIL} ${REMOTE_DOCKER_REGISTRY}
    RESULT=$?
    if [[ "$RESULT" -ne 0 ]]; then  
	    echo "Can't log in to ${REMOTE_DOCKER_REGISTRY}"
        exit
    fi
fi

REGISTRY_IMAGE="${LOCAL_IMAGE}:${IMAGE_TAG}"
FULL_REGISTRY_IMAGE="${DOCKER_REGISTRY}/${REGISTRY_IMAGE}"

# Check if image has already been pulled
sudo docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} -e ${DOCKER_EMAIL} ${DOCKER_REGISTRY}
RESULT=$?
if [[ "$RESULT" -ne 0 ]]; then  
   echo "Can't log in to ${DOCKER_REGISTRY}"
   exit
fi
sudo docker pull ${FULL_REGISTRY_IMAGE}
RESULT=$?
if [[ "$RESULT" -eq 0 ]]; then  
	echo "Image ${REGISTRY_IMAGE} present in the registry."
else
    if [[ "${PULL_IF_ABSENT}" == "true" ]]; then
        sudo docker pull ${FULL_REMOTE_IMAGE}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo "Pull of ${REMOTE_IMAGE} from ${REMOTE_DOCKER_REGISTRY} failed"
        else
            # Tag the image ready to push to the registry
            sudo docker tag ${FULL_REMOTE_IMAGE} ${FULL_REGISTRY_IMAGE}

            # Push to registry
            sudo docker push ${FULL_REGISTRY_IMAGE}
            RESULT=$?
            if [[ "$?" -ne 0 ]]; then
                echo "Couldn't push image ${REGISTRY_IMAGE} to ${FULL_REGISTRY_IMAGE}"
            fi
        fi
    fi
fi

if [[ "${PULL_IF_ABSENT}" == "true" ]]; then
    IMAGEID=$(sudo docker images | grep "${IMAGE}" | grep "${IMAGE_TAG}" | head -1 |awk '{print($3)}')
    if [[ "${IMAGEID}" != "" ]]; then
        sudo docker rmi -f ${IMAGEID}
    fi
fi
IMAGEID=$(sudo docker images | grep "${LOCAL_IMAGE}" | grep "${IMAGE_TAG}" | head -1 |awk '{print($3)}')
if [[ "${IMAGEID}" != "" ]]; then
    sudo docker rmi -f ${IMAGEID}
fi
