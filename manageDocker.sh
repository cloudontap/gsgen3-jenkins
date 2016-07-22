#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

DOCKER_TAG_DEFAULT="latest"
DOCKER_IMAGE_SOURCE_DEFAULT="remote"
DOCKER_OPERATION_DEFAULT="check"
function usage() {
    echo -e "\nManage docker images"
    echo -e "\nUsage: $(basename $0) -b -c -p -k -l DOCKER_REPO -t DOCKER_TAG -i REMOTE_DOCKER_REPO -r REMOTE_DOCKER_TAG -s DOCKER_IMAGE_SOURCE  -g DOCKER_CODE_COMMIT"
    echo -e "\nwhere\n"
    echo -e "(o) -b perform docker build and save in local registry"
    echo -e "(o) -c check if image present in local registry"
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
    echo -e "\nDEFAULTS:\n"
    echo -e "DOCKER_REPO=\"\$PROJECT/\$DOCKER_SLICE-\$DOCKER_CODE_COMMIT\" or "
    echo -e "\"\$PROJECT/\$DOCKER_CODE_COMMIT\" if no build slice defined"
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

# Parse options
while getopts ":bchki:l:pr:s:t:u:" opt; do
    case $opt in
        b)
            DOCKER_OPERATION="build"
            ;;
        c)
            DOCKER_OPERATION="check"
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
        DOCKER_REPO="${PROJECT}/${DOCKER_CODE_COMMIT}"
    else
        DOCKER_REPO="${PROJECT}/${DOCKER_SLICE}-${DOCKER_CODE_COMMIT}"
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
FULL_DOCKER_IMAGE="${PROJECT_DOCKER_DNS}/${DOCKER_IMAGE}"

# Confirm access to the local registry
sudo docker login -u ${!PROJECT_DOCKER_USER_VAR} -p ${!PROJECT_REMOTE_DOCKER_PASSWORD_VAR} -e ${PROJECT_REMOTE_DOCKER_EMAIL} ${PROJECT_DOCKER_DNS}
RESULT=$?
if [[ "$RESULT" -ne 0 ]]; then
   echo "Can't log in to ${PROJECT_DOCKER_DNS}"
   exit
fi

# Perform the required action
case ${DOCKER_OPERATION} in
    build)
        sudo docker build -t "${FULL_DOCKER_IMAGE}" .
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo "Cannot build image ${DOCKER_IMAGE}"
            exit
        fi
        sudo docker push ${FULL_DOCKER_IMAGE}
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
            echo "Unable to push ${DOCKER_IMAGE} to the local registry"
        fi
        ;;

    check)
        # Check whether the image is already in the local registry
        # Use the docker API to avoid having to download the image to check for its existence
        # Be careful of @ characters in the username or password
        DOCKER_USER=$(echo ${!PROJECT_DOCKER_USER_VAR} | sed "s/@/%40/g")
        DOCKER_PASSWORD=$(echo ${!PROJECT_DOCKER_PASSWORD_VAR} | sed "s/@/%40/g")
        DOCKER_IMAGE_COMMIT=$(curl -s https://${DOCKER_USER}:${DOCKER_PASSWORD}@${PROJECT_DOCKER_API_DNS}/v1/repositories/${DOCKER_REPO}/tags | jq ".[\"${DOCKER_TAG}\"] | select(.!=null)")

        if [[ -n "${DOCKER_IMAGE_COMMIT}" ]]; then
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
        FULL_REMOTE_DOCKER_IMAGE="${PROJECT_DOCKER_DNS}/${REMOTE_DOCKER_IMAGE}"

        # Pull in the local image
        sudo docker pull ${FULL_DOCKER_IMAGE}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo "Can't pull ${DOCKER_IMAGE} from ${PROJECT_DOCKER_DNS}"
        else
            # Tag the image ready to push to the registry
            sudo docker tag ${FULL_DOCKER_IMAGE} ${FULL_REMOTE_DOCKER_IMAGE}
            RESULT=$?
            if [[ "$?" -ne 0 ]]; then
                echo "Couldn't tag image ${FULL_DOCKER_IMAGE} with ${FULL_REMOTE_DOCKER_IMAGE}"
            else
                # Push to registry
                sudo docker push ${FULL_REMOTE_DOCKER_IMAGE}
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
                FULL_REMOTE_DOCKER_IMAGE="${PROJECT_REMOTE_DOCKER_DNS}/${REMOTE_DOCKER_IMAGE}"

                # Confirm access to the remote registry
                sudo docker login -u ${!PROJECT_REMOTE_DOCKER_USER_VAR} -p ${!PROJECT_REMOTE_DOCKER_PASSWORD_VAR} -e ${PROJECT_REMOTE_DOCKER_EMAIL} ${PROJECT_REMOTE_DOCKER_DNS}
                RESULT=$?
                if [[ "$RESULT" -ne 0 ]]; then
                    echo "Can't log in to ${PROJECT_REMOTE_DOCKER_DNS}"
                    exit
                fi
                ;;
                
            *)
                FULL_REMOTE_DOCKER_IMAGE="${REMOTE_DOCKER_IMAGE}"
                ;;
        esac

        # Pull in the remote image
        sudo docker pull ${FULL_REMOTE_DOCKER_IMAGE}
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            echo "Can't pull ${REMOTE_DOCKER_IMAGE} from ${PROJECT_REMOTE_DOCKER_DNS}"
        else
            # Tag the image ready to push to the registry
            sudo docker tag ${FULL_REMOTE_DOCKER_IMAGE} ${FULL_DOCKER_IMAGE}
            RESULT=$?
            if [[ "$?" -ne 0 ]]; then
                echo "Couldn't tag image ${FULL_REMOTE_DOCKER_IMAGE} with ${FULL_DOCKER_IMAGE}"
            else
                # Push to registry
                sudo docker push ${FULL_DOCKER_IMAGE}
                RESULT=$?
                if [[ "$?" -ne 0 ]]; then
                    echo "Unable to push ${DOCKER_IMAGE} to the registry"
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

IMAGEID=$(sudo docker images | grep "${REMOTE_DOCKER_REPO}" | grep "${REMOTE_DOCKER_TAG}" | head -1 |awk '{print($3)}')
if [[ "${IMAGEID}" != "" ]]; then
    sudo docker rmi -f ${IMAGEID}
fi

IMAGEID=$(sudo docker images | grep "${DOCKER_REPO}" | grep "${DOCKER_TAG}" | head -1 |awk '{print($3)}')
if [[ "${IMAGEID}" != "" ]]; then
    sudo docker rmi -f ${IMAGEID}
fi

