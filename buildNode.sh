#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

if [[ -z "${PROJECT}" ]]; then
    PROJECT=$(echo ${JOB_NAME,,} | cut -d '-' -f 1)
fi

if [[ -z "${SLICE}" ]]; then
    if [ -e slice.ref ]; then
        SLICE=`cat slice.ref`
    fi
fi

# Perform checks for Docker packaging
if [[ -f Dockerfile ]]; then
    if [[ -z "${REMOTE_REPO}" ]]; then
        if [[ "${SLICE}" == "" ]]; then
            REMOTE_REPO="${PROJECT}/${GIT_COMMIT}"
        else
            REMOTE_REPO="${PROJECT}/${SLICE}/${GIT_COMMIT}"
        fi
    fi
    
    ${GSGEN_JENKINS}/manageDockerImage.sh -c -s local -i ${REMOTE_REPO}
    RESULT=$?
    if [[ "${RESULT}" -eq 0 ]]; then
        echo "Image ${REMOTE_REPO} already exists"
        exit
    fi
fi

# TODO: Perform checks for AWS Lambda packaging - not sure yet what to check for as a marker

npm install --unsafe-perm
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "npm install failed, exiting..."
   exit
fi

# TODO: Confirm if these are needed.
# npm install -g bower
# npm install -g grunt

# TODO: Optionally run bower as part of the build
# bower install --allow-root

# TODO: Confirm if required and add check for error code
# grunt test

npm rebuild
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "npm rebuild failed, exiting..."
   exit
fi

grunt build
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "grunt build failed, exiting..."
   exit
fi

npm prune --production &&   npm install --production --unsafe-perm &&   npm rebuild

# Package for docker if required
if [[ -f Dockerfile ]]; then
    sudo docker build -t ${FULL_IMAGE} .
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo "Cannot build image ${REMOTE_REPO}, exiting..."
       exit
    fi
    
    sudo docker push ${FULL_IMAGE}
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
       echo "Unable to push ${REMOTE_REPO} to registry"
       IMAGEID=`docker images|grep $GIT_COMMIT|head -1|awk '{print($3)}'`
       docker rmi -f $IMAGEID
       exit
    fi
    
    # Cleanup images locally
    IMAGEID=`sudo docker images|grep $GIT_COMMIT|head -1|awk '{print($3)}'`
    sudo docker rmi -f $IMAGEID
    echo "GIT_COMMIT=$GIT_COMMIT" > $WORKSPACE/context.properties
    
    if [[ -z "${SLICE}" ]]; then
        SLICE="www"
    fi
fi

# TODO: Package for AWS Lambda if required - not sure yet what to check for as a marker

echo "PROJECT=$PROJECT" >> $WORKSPACE/context.properties
echo "SLICE=$SLICE" >> $WORKSPACE/context.properties
