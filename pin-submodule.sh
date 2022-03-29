#!/usr/bin/env bash

################################################################################
#   Check required commands                                                    #
################################################################################
REQUIRED_CMDS=("git" "curl" "jq")
MISSING_CMDS=()
for cmd in ${REQUIRED_CMDS[@]}; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_CMDS+=($cmd)
    fi
done
if [[ ${#MISSING_CMDS[@]} != 0 ]]; then
    echo "The following commands are required and missing: ${MISSING_CMDS[@]}"
    echo "Exiting..."
    exit 1
fi


################################################################################
#   Main Script Usage                                                          #
################################################################################
usage() {
cat << EOF
$0 [SUBMODULE] [OPTIONS]

Pin a submodule

SUBMODULE:
    config  CoreOS Assembler configuration
    k3s     K3S
EOF
}

################################################################################
#   CoreOS Configuration Submodule Functions                                   #
################################################################################
DIR_CONFIG="fedora-coreos-config"

usageConfig() {
cat << EOF
$0 config [OPTIONS]

Pin upstream CoreOS Assembler configuration.
Specify branch and either latest or commit hash.

    $0 config -b stable -l
    $0 config -b stable -c f1962b5

OPTIONS:
    -l      Latest
    -b      Branch
    -c      Commit Hash / ID
EOF
}

pinConfig() {
    local latest=false
    local branch=""
    local commit=""
    if [ $# -eq 0 ]; then usageConfig; echo "Missing option"; exit 1; fi
    while getopts b:c:l options; do
        case $options in
            b)  branch=$OPTARG  ;;
            c)  commit=$OPTARG  ;;
            l)  latest=true     ;;
        esac
    done
    if [ $latest = true ] && [[ $commit != "" ]]; then
        usageConfig
        echo "Option \"-l\" and \"-c\" conflict"
        exit 1
    fi
    if [ $latest = false ] && [[ $commit == "" ]]; then
        usageConfig
        echo "Option \"-l\" OR \"-c\" are required"
        exit 1
    fi
    git -C $DIR_CONFIG fetch --all
    git submodule set-branch --branch $branch $DIR_CONFIG
    if [ $latest = true ]; then
        git submodule update --remote --checkout $DIR_CONFIG
    fi
    if [[ $commit != "" ]]; then
        git -C $DIR_CONFIG reset --hard $commit
    fi

    # Clean and relink root files
    find . -maxdepth 1 -type l -exec unlink {} \;
    for f in fedora-coreos-config/manifest-lock.*; do ln -s "$f"; done
    ln -s fedora-coreos-config/fedora-coreos-pool.repo
    ln -s fedora-coreos-config/live

    # Clean and relink overlays
    cd overlay.d
    find . -maxdepth 1 -type l -exec unlink {} \;
    for f in ../fedora-coreos-config/overlay.d/*/; do ln -s ${f%*/}; done
    cd ..
}

################################################################################
#   k3s Submodule Functions                                                    #
################################################################################
DIR_K3S="k3s"

usageK3S() {
cat << EOF
$0 k3s [OPTIONS]

Pin upstream k3s.

Specify either latest or a release tag.

    $0 k3s -l
    $0 k3s -t v1.22.4+k3s1

OPTIONS:
    -l      Latest
    -t      Release Tag
EOF
}

pinK3S() {
    local latest=false
    local tag=""
    if [ $# -eq 0 ]; then usageK3S; echo "Missing option"; exit 1; fi
    while getopts t:l options; do
        case $options in
            l)  latest=true ;;
            t)  tag=$OPTARG ;;
        esac
    done
    if [ $latest = true ] && [[ $tag != "" ]]; then
        usageK3S
        echo "Option \"l\" and \"-t\" conflict"
        exit 1
    fi
    if [ $latest = false ] && [[ $tag == "" ]]; then
        usageK3S
        echo "Option \"-l\" OR \"-t\" are required"
        exit 1
    fi
    git -C $DIR_K3S fetch --all --tags
    if [ $latest = true ]; then
        local url="https://api.github.com/repos/k3s-io/k3s/releases/latest"
        local latest_release=$(curl -s $url)
        tag=$(echo $latest_release | jq -r '.tag_name')
    fi
    git -C $DIR_K3S reset --hard tags/$tag
    status=$?
    [ $status -ne 0 ] && exit $status
    dropinPath="overlay.d/30k3s/usr/lib/systemd/system/k3s-install.service.d"
    dropinContent="[Service]\nEnvironment=INSTALL_K3S_VERSION=$tag"
    echo -e $dropinContent > "${dropinPath}/10-pin-version.conf"
}

################################################################################
#   Main                                                                       #
################################################################################
if [ $# -eq 0 ]; then usage; exit 1; fi
case "$1" in
    config) pinConfig ${@:2}    ;;
    k3s)    pinK3S ${@:2}       ;;
    *)
        usage
        echo "Unknown submodule \"$1\""
        exit 1
        ;;
esac

./build-manifest.sh