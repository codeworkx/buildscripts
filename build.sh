#!/bin/bash

CMD="$1"
EXTRACMD="$2"
A_TOP=${PWD}
CUR_DIR=`dirname $0`
DATE=$(date +%D)
ROM_NAME="lineage"
ROM_VERSION=18.1

# Common defines (Arch-dependent)
case `uname -s` in
    Darwin)
        txtrst='\033[0m'  # Color off
        txtred='\033[0;31m' # Red
        txtgrn='\033[0;32m' # Green
        txtylw='\033[0;33m' # Yellow
        txtblu='\033[0;34m' # Blue
        THREADS=`sysctl -an hw.logicalcpu`
        ;;
    *)
        txtrst='\e[0m'  # Color off
        txtred='\e[0;31m' # Red
        txtgrn='\e[0;32m' # Green
        txtylw='\e[0;33m' # Yellow
        txtblu='\e[0;34m' # Blue
        THREADS=`cat /proc/cpuinfo | grep processor | wc -l`
        ;;
esac

check_root() {
    if [ ! $( id -u ) -eq 0 ]; then
        echo -e "${txtred}Please run this script as root."
        echo -e "\r\n ${txtrst}"
        exit
    fi
}

gerrit_apply_topic()
{
    if [[ ! -z ${1} && ! ${1} == " " ]]; then
        echo -e "${txtylw}Applying gerrit topic: ${1} ${txtrst}"
        python $CUR_DIR/vendor/lineage/build/tools/repopick.py --topic ${1} --ignore-missing --start-branch auto
        if [[ ${PIPESTATUS[0]} != 0 ]]; then
            echo -e "${txtred}Applying gerrit topic ${1} failed!${txtrst}"
            exit 1
        fi
    else
        echo -e "${txtred}Invalid topic: ${1} ${txtrst}"
    fi
}

gerrit_apply_change()
{
    if [[ ! -z ${1} && ! ${1} == " " ]]; then
        echo -e "${txtylw}Applying gerrit change: ${1} ${txtrst}"
        python $CUR_DIR/vendor/lineage/build/tools/repopick.py ${1} --ignore-missing --start-branch auto
        if [[ ${PIPESTATUS[0]} != 0 ]]; then
            echo -e "${txtred}Applying gerrit change ${1} failed!${txtrst}"
            exit 1
        fi
    else
        echo -e "${txtred}Invalid change: ${1} ${txtrst}"
    fi
}

github_checkout()
{
    if [[ ! -z ${1} && ! ${1} == " " && ! -z ${2} && ! ${2} == " " && ! -z ${3} && ! ${3} == " " ]]; then
        echo -e "${txtylw}Doing github checkout on ${1} ${txtrst}"

        echo -e "${txtblu}Repo: ${2} ${txtrst}"
        echo -e "${txtblu}Ref: ${3} ${txtrst}"
        echo -e "${txtblu}Target: ${1} ${txtrst}"

        pushd ${1}
        # Create auto branch
        repo start auto
        # Do checkout
        git fetch https://github.com/${2} ${3} && git checkout FETCH_HEAD
        popd

        if [[ ${PIPESTATUS[0]} != 0 ]]; then
            echo -e "${txtred}Checkout on ${1} failed!${txtrst}"
            exit 1
        fi

    else
        echo -e "${txtred}Invalid checkout: ${1} ${txtrst}"
    fi
}

local_apply_patch()
{
    if [[ ! -z ${1} && ! ${1} == " " && ! -z ${2} && ! ${2} == " " ]]; then
        echo -e "${txtylw}Applying local patch: ${2} ${txtrst}"

        if [ ! -f ${2} ]; then
            echo "Patchfile ${2} does not exist."
            exit 1
        fi

        echo -e "${txtblu}Patch: ${2} ${txtrst}"
        echo -e "${txtblu}Target: ${1} ${txtrst}"

        pushd ${1}
        # Create auto branch
        repo start auto
        # Apply patch
        git am ${A_TOP}/${2}
        popd

        if [[ ${PIPESTATUS[0]} != 0 ]]; then
            echo -e "${txtred}Applying local patch ${1} failed!${txtrst}"
            exit 1
        fi

    else
        echo -e "${txtred}Invalid local patch: ${1} ${txtrst}"
    fi
}

echo -e "${txtblu} #########################################################################"
echo -e "${txtblu} \r\n"
echo -e "${txtblu}  ██╗     ██╗███╗   ██╗███████╗ █████╗  ██████╗ ███████╗ ██████╗ ███████╗ "
echo -e "${txtblu}  ██║     ██║████╗  ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝██╔═══██╗██╔════╝ "
echo -e "${txtblu}  ██║     ██║██╔██╗ ██║█████╗  ███████║██║  ███╗█████╗  ██║   ██║███████╗ "
echo -e "${txtblu}  ██║     ██║██║╚██╗██║██╔══╝  ██╔══██║██║   ██║██╔══╝  ██║   ██║╚════██║ "
echo -e "${txtblu}  ███████╗██║██║ ╚████║███████╗██║  ██║╚██████╔╝███████╗╚██████╔╝███████║ "
echo -e "${txtblu}  ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝ "
echo -e "${txtblu} \r\n"
echo -e "${txtblu}                   LineageOS ${ROM_VERSION} buildscript"
echo -e "${txtblu}                   visit us @ http://www.lineageos.org"
echo -e "${txtblu} \r\n"
echo -e "${txtblu} #########################################################################"
echo -e "\r\n ${txtrst}"

# Check for build target
if [ -z "${CMD}" ]; then
    echo -e "${txtred}No build target set."
    echo -e "${txtred}Usage: ./build.sh mako (complete build)"
    echo -e "${txtred}       ./build.sh mako boot (bootimage only)"
    echo -e "${txtred}       ./build.sh mako recovery (recoveryimage only)"
    echo -e "${txtred}       ./build.sh clean (make clean)"
    echo -e "${txtred}       ./build.sh clobber (make clober, wipes entire out/ directory)"
    echo -e "\r\n ${txtrst}"
    exit
fi

# Starting Timer
START=$(date +%s)

case "$EXTRACMD" in
    eng)
        BUILD_TYPE=eng
        ;;
    userdebug)
        BUILD_TYPE=userdebug
        ;;
    *)
        BUILD_TYPE=eng
        ;;
esac

# Device specific settings
case "$CMD" in
    clean)
        make clean
        rm -rf ./out/target/product
        exit
        ;;
    clobber)
        make clobber
        exit
        ;;
    *)
        lunch=${ROM_NAME}_${CMD}-${BUILD_TYPE}
        brunch=${lunch}
        ;;
esac

# create env.sh if it doesn't exist
if [ ! -f $CUR_DIR/env.sh ]; then
    # Enable ccache
    echo "export USE_CCACHE=1" > env.sh
    # Fix for Archlinux
    echo "export LC_ALL=C" > env.sh
fi

# create empty patches.txt if it doesn't exist
if [ ! -f $CUR_DIR/patches.txt ]; then
    touch patches.txt
fi

# Setting up Build Environment
echo -e "${txtgrn}Setting up Build Environment...${txtrst}"
. build/envsetup.sh
lunch ${lunch}

# Allow setting of additional flags
if [ -f $CUR_DIR/env.sh ]; then
    source $CUR_DIR/env.sh
fi

# Apply changes from patches.txt.
# Commands:
#   123456                                                                                          // Cherry pick specific change-id
#   checkout packages/apps/Settings LineageOS/android_packages_apps_Settings refs/changes/1/1/1     // Do a github checkout
#   topic oreo-bringup                                                                              // Cherry pick all changes with specific topic
#   local vendor/lineage 0001-disable-security.patch                                                // Apply local patch
#   sync    
#                                                                                        // Do repo sync
if [ -f $CUR_DIR/patches.txt ]; then
    echo -e "${txtylw}Applying patches from patches.txt...${txtrst}"
    repo abandon auto

    # Read patch data
    while read line; do
        case $line in
            checkout*)
                IFS=' ' read -a patchdata <<< "$line"
                github_checkout ${patchdata[1]} ${patchdata[2]} ${patchdata[3]}
                ;;
            local*)
                IFS=' ' read -a patchdata <<< "$line"
                local_apply_patch ${patchdata[1]} ${patchdata[2]}
                ;;
            [0-9]*)
                IFS=' ' read -a patchdata -d "#" <<< "$line"
                gerrit_apply_change ${patchdata[0]}
                ;;
            topic*)
                IFS=' ' read -a patchdata -d "#" <<< "$line"
                gerrit_apply_topic ${patchdata[1]}
                ;;
            sync)
                echo -e "${txtylw}Syncing...${txtrst}"
                repo sync -j20
                ;;
        esac
    done < patches.txt
    echo -e "${txtgrn}...done${txtrst}"
fi

# Prebuild script
if [ -f $CUR_DIR/prebuild.sh ]; then
    source $CUR_DIR/prebuild.sh
fi

# Start the Build
case "$EXTRACMD" in
    boot)
        echo -e "${txtgrn}Rebuilding bootimage...${txtrst}"

        rm ${ANDROID_PRODUCT_OUT}/kernel
        rm ${ANDROID_PRODUCT_OUT}/boot.img
        rm -rf ${ANDROID_PRODUCT_OUT}/root
        rm -rf ${ANDROID_PRODUCT_OUT}/ramdisk*
        rm -rf ${ANDROID_PRODUCT_OUT}/combined*

        mka bootimage
        if [ ! -e ${ANDROID_PRODUCT_OUT}/obj/EXECUTABLES/updater_intermediates/updater ]; then
            mka updater
        fi
        if [ ! -e ${ANDROID_HOST_OUT}/framework/signapk.jar ]; then
            mka signapk
        fi
        ;;
    recovery)
        echo -e "${txtgrn}Rebuilding recoveryimage...${txtrst}"

        rm -rf ${ANDROID_PRODUCT_OUT}/obj/KERNEL_OBJ
        rm ${ANDROID_PRODUCT_OUT}/kernel
        rm ${ANDROID_PRODUCT_OUT}/recovery.img
        rm ${ANDROID_PRODUCT_OUT}/recovery
        rm -rf ${ANDROID_PRODUCT_OUT}/ramdisk*

        mka ${ANDROID_PRODUCT_OUT}/recovery.img
        ;;
    *)
        echo -e "${txtgrn}Building LineageOS ${ROM_VERSION}...${txtrst}"
        brunch ${brunch}
        ;;
esac

END=$(date +%s)
ELAPSED=$((END - START))
E_MIN=$((ELAPSED / 60))
E_SEC=$((ELAPSED - E_MIN * 60))
printf "${txtgrn}Elapsed: "
[ $E_MIN != 0 ] && printf "%d min(s) " $E_MIN
printf "%d sec(s)\n ${txtrst}" $E_SEC

# Postbuild script for uploading builds
if [ -f $CUR_DIR/postbuild.sh ]; then
    source $CUR_DIR/postbuild.sh
fi
