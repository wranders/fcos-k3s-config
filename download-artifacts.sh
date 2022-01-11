#!/usr/bin/env bash

################################################################################
#   Check required commands                                                    #
################################################################################
REQUIRED_CMDS=("git" "curl" "sha256sum")
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
FORCE=false
ARCH=()
SUFFIX=()

################################################################################
#   Main Script Usage                                                          #
################################################################################
usage() {
cat << EOF
usage: $0 [ -h ] | [ -A | -a [arch] ] [ -f ]

OPTIONS
    -A      All architectures (amd64 + arm64)
    -a      Architecture (x86_64, amd64, aarch64, arm64)
    -f      Force. Overwrite existing artifacts
    -h      Show this dialog
EOF
    if [ $1 ]; then
        exit 0;
    else
        exit 1;
    fi
}

################################################################################
#   Download Artifacts Associated with Pinned ks Version                       #
################################################################################
download() {
    local k3sVersion=$(git -C k3s describe --tags)
    local releaseUrl="https://github.com/k3s-io/k3s/releases/download/$k3sVersion"
    for (( i=0; i < ${#ARCH[@]}; i++ )); do
        local arch=${ARCH[$i]}
        local suffix=${SUFFIX[$i]}
        local downloadDir="downloads/$k3sVersion/$arch"
        local -a files=(
            "$releaseUrl/sha256sum-$arch.txt"
            "$releaseUrl/k3s$suffix"
            "$releaseUrl/k3s-airgap-images-$arch.tar.gz"
        )
        for url in ${files[@]}; do
            local filename=$(echo $url | sed -u 's/.*\///')
            local filepath=$downloadDir/$filename
            if [ $FORCE == true ] && [ -f $filepath ]; then
                echo "$filepath exists; skipping"
                continue
            fi
            echo $filename
            COLUMNS=50 curl -# -LO --create-dirs --output-dir $downloadDir $url
        done
        wait
        cd $downloadDir
        sha256sum -c --ignore-missing --status sha256sum-$arch.txt
        if [ $? -ne 0 ]; then 
            # TODO: Improve checksum error reporting
            echo "Checksum wrong; exiting"
            exit 1
        fi
        cd - >/dev/null
    done
}

################################################################################
#   Parse Arguments                                                            #
################################################################################
while getopts Aa:fh options; do
    case $options in
        A)  ARCH=("amd64" "arm64") SUFFIX=("" "-arm64") ;;
        a) ([ ${#ARCH[@]} -ne 0 ] && usage) || 
            case "$OPTARG" in
                x86_64  | amd64) ARCH=("amd64") SUFFIX=("")       ;;
                aarch64 | arm64) ARCH=("arm64") SUFFIX=("-arm64") ;;
                # FCOS doesn't ship 32-bit ARM images, so we won't either.
                # Leaving this in place if they decide to in the future.
                # arm*) ARCH=("arm") SUFFIX=("-armhf") ;;
                *)
                    usage
                    echo "Unsupported CPU architecture \"$OPTARG\""
                    exit 1 ;;
            esac ;;
        f)  FORCE=true ;;
        h)  usage 1 ;;
    esac
done

if [ ${#ARCH[@]} -eq 0 ]; then
    case $(uname -m) in
        x86_64  | amd64) ARCH=("amd64") SUFFIX=("")       ;;
        aarch64 | arm64) ARCH=("arm64") SUFFIX=("-arm64") ;;
        # arm*)          ARCH=("arm")   SUFFIX=("-armhf") ;;
        *)
            usage
            echo "Unsupported CPU architecture \"$OPTARG\""
            exit 1 ;;
    esac
fi

################################################################################
#   Run Main Script                                                            #
################################################################################
download
