#!/bin/bash

if [[ -n "${GSGEN_DEBUG}" ]]; then set ${GSGEN_DEBUG}; fi

trap 'exit ${RESULT:-0}' EXIT SIGHUP SIGINT SIGTERM

if [[ "${CREATE_ACCOUNT_REPOS}" == "true" ]]; then

    ${GSGEN_JENKINS}/constructTree.sh -a -p
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo "Can't construct the account directory tree"
        exit
    fi

    # Initialise the config tree
    mkdir config/${OAID}
    cd ${WORKSPACE}/${OAID}/config/${OAID}
    
    # TODO: Populate the organisation.json and account.json files
    touch readme.md

    # Initialise the config repo
    git init
    git config user.name  "${GIT_USER}"
    git config user.email "${GIT_EMAIL}"
    git add *
    git commit -m "Initial version"
    git remote add origin https://${GITHUB_USER}:${GITHUB_PASS}@${OAID_CONFIG_REPO}
	git push origin master
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Unable to initialise the config repo"
        exit
    fi

    # Initialise the infrastructure tree
    mkdir infrastructure/${OAID}
    cd ${WORKSPACE}/${OAID}/infrastructure/${OAID}

    # TODO: Populate the credentials.json file for the account
    touch readme.md

    # Initialise the infrastructure repo
    git init
    git config user.name  "${GIT_USER}"
    git config user.email "${GIT_EMAIL}"
    git add *
    git commit -m "Initial version"
    git remote add origin https://${GITHUB_USER}:${GITHUB_PASS}@${OAID_INFRASTRUCTURE_REPO}
	git push origin master
    RESULT=$?
    if [[ "${RESULT}" -ne 0 ]]; then
        echo "Unable to initialise the infrastructure repo"
        exit
    fi
else
    ${GSGEN_JENKINS}/constructTree.sh -p
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        echo "Can't construct the account directory tree"
        exit
    fi
fi

find ${OAID}/infrastructure/startup -name ".git*" -exec rm -rf {} \;

