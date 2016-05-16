#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

if [[ -z "${PROJECT}" ]]; then
    PROJECT=$(echo ${JOB_NAME,,} | cut -d '-' -f 1)
fi

if [[ -z "${IMAGE}" ]]; then
    IMAGE="${PROJECT}/${GIT_COMMIT}"
fi

FULL_IMAGE="${DOCKER_REGISTRY}/${IMAGE}"

sudo docker login -u $DOCKER_USER -p $DOCKER_PASS -e $DOCKER_EMAIL $DOCKER_REGISTRY
RESULT=$?
if [ "$RESULT" -ne 0 ] ;  
  then  
   echo "Cannot login to docker, exiting..."
   exit
fi

sudo docker pull ${FULL_IMAGE}
RESULT=$?
if [ "$RESULT" -eq 0 ] ;  
  then  
   echo "Image ${IMAGE} already exists"  
   IMAGEID=`docker images|grep $GIT_COMMIT|head -1|awk '{print($3)}'`
   docker rmi -f $IMAGEID
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
   echo "Cannot build image ${IMAGE}, exiting..."
   exit
fi

sudo docker push ${FULL_IMAGE}
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "Unable to push ${IMAGE} to registry"  
   IMAGEID=`docker images|grep $GIT_COMMIT|head -1|awk '{print($3)}'`
   docker rmi -f $IMAGEID
   exit
fi

# Cleanup images locally
IMAGEID=`sudo docker images|grep $GIT_COMMIT|head -1|awk '{print($3)}'`
sudo docker rmi -f $IMAGEID
echo "GIT_COMMIT=$GIT_COMMIT" > $WORKSPACE/image_ref

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

echo "PROJECT=$PROJECT" >> $WORKSPACE/context.ref
echo "SLICE=$SLICE" >> $WORKSPACE/context.ref
