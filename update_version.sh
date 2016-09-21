#!/bin/bash -e

#This script is used during the release process. It is not intended to be ran manually.

VERSION="$1"
VERSION="${VERSION:?"must provide version as first parameter"}"
SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"

updateVersion(){
    updateGemspec
    commitStagedFiles "Update version to ${VERSION}"
}

updateGemspec(){
    echo -e "\nUpdating gemspec version"
    local gemspecPath="${SCRIPT_DIR}/mercury_amqp.gemspec"
    sed -i 's/\(\.version\s*=\s*\).*/\1'"'${VERSION}'/" "${gemspecPath}"
    stageFiles "${gemspecPath}"
}

stageAndCommit(){
    local msg="$1"
    shift
    local files=( "$@" )
    stageFiles "${files[@]}"
    commitStagedFiles "${msg}"
}

stageFiles(){
    local files=( "$@" )
    git add "${files[@]}"
}

commitStagedFiles(){
    local msg="$1"
    if thereAreStagedFiles; then
        git commit -m "${msg}"
    else
        echo "No changes to commit"
    fi
}

thereAreStagedFiles(){
    git update-index -q --ignore-submodules --refresh
    if git diff-index --cached --quiet HEAD --ignore-submodules -- ; then
        return 1;
    else
        return 0;
    fi
}

updateVersion
