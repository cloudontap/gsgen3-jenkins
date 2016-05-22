#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

if [[ -z "${PROJECT}" ]]; then
    PROJECT=$(echo ${JOB_NAME,,} | cut -d '-' -f 1)
fi

if [[ -z "${REMOTE_REPO}" ]]; then
    REMOTE_REPO="${PROJECT}/${GIT_COMMIT}"
fi

FULL_IMAGE="${DOCKER_REGISTRY}/${REMOTE_REPO}"
${GSGEN_JENKINS}/manageDockerImage.sh -c
RESULT=$?
if [[ "${RESULT}" -eq 0 ]]; then
    echo "Image ${REMOTE_REPO} already exists"
    exit
fi

cd laravel/

/usr/local/bin/composer install --prefer-source --no-interaction
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "composer install fails with the exit code $RESULT, exiting..."
   exit
fi

/usr/local/bin/composer update
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "composer update fails with the exit code $RESULT, exiting..."
   exit
fi

cd ../

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
    if [ -e slice.ref ]; then
        SLICE=`cat slice.ref`
        if [ -z "${SLICE}" ]; then
            SLICE="www"
        fi
    else
        SLICE="www"
    fi
fi

echo "PROJECT=$PROJECT" >> $WORKSPACE/context.properties
echo "SLICE=$SLICE" >> $WORKSPACE/context.properties
