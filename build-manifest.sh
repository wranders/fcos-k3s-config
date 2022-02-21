#!/usr/bin/env bash

################################################################################
#   Check required commands                                                    #
################################################################################
REQUIRED_CMDS=("git")
MISSING_CMDS=()
for cmd in ${REQUIRED_CMDS[@]}; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_CMDS+=($cmd)
    fi
done
if [[ ${#MISSING_CMDS[@]} != 0 ]]; then
    echo "The following command are required and missing: ${MISSING_CMDS[@]}"
    echo "Exiting..."
    exit 1
fi

################################################################################
#   Top Level Variables                                                        #
################################################################################
MANIFEST="manifest.yaml"
MANIFEST_TEMPLATE="${MANIFEST}.tmpl"
MANIFEST_CONTENTS=$(cat $MANIFEST_TEMPLATE)

################################################################################
#   Build Manifest from Template                                               #
################################################################################
buildManifest() {
    local remote=$(git -C fedora-coreos-config branch --remote --contains)
    if [[ $remote == *"->"* ]]; then
        remote=$(echo $remote | awk -F'-> .* ' '{print $2}' | cut -d/ -f2)
    fi
    local branch=$(echo $remote | cut -d/ -f2)
    local stream=""
    # Determined in accordance with 
    # https://github.com/coreos/fedora-coreos-tracker/blob/main/Design.md#version-numbers
    case "$branch" in
        next)           stream="1"    ;;
        testing)        stream="2"    ;;
        stable)         stream="3"    ;;
        next-devel)     stream="10"   ;;
        testing-devel)  stream="20"   ;;
        rawhide)        stream="91"   ;;
        branched)       stream="92"   ;;
        bodhi-updates)  stream="94"   ;;
        *)              stream="0"    ;;
    esac
    local k3sVer=$(git -C k3s describe --tags)
    # Replace + with - because + is an unsupported character in the version prefix
    local k3sVerEsc=${k3sVer//[+]/-}
    local versionPrefix="\${releasever}.<date:%Y%m%d>.$stream-$k3sVerEsc"
    
    # Set Version Prefix
    local search="^automatic-version-prefix.*"
    local replace="automatic-version-prefix: \"$versionPrefix\""
    MANIFEST_CONTENTS=$(echo "$MANIFEST_CONTENTS" | sed "s/$search/$replace/")

    # Set Distribution ref
    search="^ref: fedora\/\${basearch}\/coreos\/k3s\/.*"
    replace="ref: fedora\/\${basearch}\/coreos\/k3s\/$branch"
    MANIFEST_CONTENTS=$(echo "$MANIFEST_CONTENTS" | sed "s/$search/$replace/")
}

################################################################################
#   Write Manifest Contents to File                                            #
################################################################################
writeManifest() {
    echo "$MANIFEST_CONTENTS" > $MANIFEST
    echo "$MANIFEST created"
}

################################################################################
#   Run Main Script                                                            #
################################################################################
buildManifest
writeManifest