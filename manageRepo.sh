#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-1}' EXIT SIGHUP SIGINT SIGTERM

REPO_OPERATION_DEFAULT="update"
REMOTE_REPO_DEFAULT="origin"
REMOTE_BRANCH_DEFAULT="master"
function usage() {
    echo -e "\nManage repos"
    echo -e "\nUsage: $(basename $0) -n REPO_NAME -m REPO_MESSAGE -t REPO_TAG -r REMOTE_REPO -b REMOTE_BRANCH -u"
    echo -e "\nwhere\n"
    echo -e "    -h shows this text"
    echo -e "(o) -m REPO_MESSAGE is used as the commit/tag message"
    echo -e "(o) -n REPO_NAME to use in log messages"
    echo -e "(o) -t REPO_TAG is the tag to add after commit"
    echo -e "(o) -u update local repo and push to origin"
    echo -e "\nDEFAULTS:\n"
    echo -e "REPO_OPERATION=${REPO_OPERATION_DEFAULT}"
    echo -e "REMOTE_REPO=${REMOTE_REPO_DEFAULT}"
    echo -e "REMOTE_BRANCH=${REMOTE_BRANCH_DEFAULT}"
    echo -e "\nNOTES:\n"
    echo -e ""
    exit
}
# Parse options
while getopts ":hm:n:t:u"
    case $opt in
        h)
            usage
            ;;
        m)
            REPO_MESSAGE="${OPTARG}"
            ;;
        n)
            REPO_NAME="${OPTARG}"
            ;;
        m)
            REPO_MESSAGE="${OPTARG}"
            ;;
        t)
            REPO_TAG="${OPTARG}"
            ;;
        u)
            DOCKER_OPERATION="update"
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

# Apply defaults
REPO_OPERATION="${REPO_OPERATION:-$REPO_OPERATION_DEFAULT}"
REMOTE_REPO="${REMOTE_REPO:-$REMOTE_REPO_DEFAULT}"
REMOTE_BRANCH="${REMOTE_BRANCH:-$REMOTE_BRANCH_DEFAULT}"

# Perform the required action
case ${DOCKER_OPERATION} in
    update)

        # Ensure git knows who we are
        git config user.name  "${GIT_USER}"
        git config user.email "${GIT_EMAIL}"
        
        # Add anything that has been added/modified/deleted
        git add -A
        
        # Commit the changes
        echo "Committing to the ${REPO_NAME} repo..."
        git commit -m "${REPO_MESSAGE}"
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't commit to the ${REPO_NAME} repo, exiting..."
            exit
        fi
        
        # Tag the commit if required
        if [[ -n "${REPO_TAG}" ]]; then
            echo "Adding tag \"${REPO_TAG}\" to the ${REPO_NAME} repo..."
            git tag -a ${REPO_TAG} -m "${REPO_MESSAGE}"
            RESULT=$?
            if [[ ${RESULT} -ne 0 ]]; then
                echo "Can't tag the ${REPO_NAME} repo, exiting..."
                exit
            fi
        fi
        
        # Update upstream repo
        git push --tags ${REMOTE_REPO} ${REMOTE_BRANCH}
        RESULT=$?
        if [[ ${RESULT} -ne 0 ]]; then
            echo "Can't push the ${REPO_NAME} repo changes to upstream repo ${REMOTE_REPO}, exiting..."
            exit
        fi
        ;;
esac

# All good
RESULT=0
