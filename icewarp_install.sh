#!/bin/bash
#
# IceWarp Server installation script
# Copyright (c) 2008-2015 IceWarp Ltd. All rights reserved.
#
# http://www.icewarp.com 
#
# file: install.sh - install script
# version: 1.5
#

# variables
EMPTY_VALUE="UNKNOWN"

USE_COLORS="0"

IMAGENAME="IceWarpServer-image-12.0.0.0_20170125_RHEL7_x64.tar"

SETUP_NEWVERSION="12.0.0.0 (2017-01-25) RHEL7 x64"
SETUP_OLDVERSION="$EMPTY_VALUE"

SETUP_SERVER_PLATFORM="x86_64"
SETUP_SERVER_OLDPLATFORM="${EMPTY_VALUE}"

SETUP_SERVER_LIBDIR="lib64"

SETUP_INSTALL_DIR="$EMPTY_VALUE"
SETUP_INSTALL_DIR_DEFAULT="/opt/icewarp"

SETUP_CONFIG_DIR=""
SETUP_CONFIG_DIR_DEFAULT="config"

SETUP_CALENDAR_DIR=""
SETUP_CALENDAR_DIR_DEFAULT="calendar"

SETUP_SPAM_DIR=""
SETUP_SPAM_DIR_DEFAULT="spam"

SETUP_INSTALL_USER="$EMPTY_VALUE"
SETUP_INSTALL_USER_DEFAULT=$(id -un)

SETUP_INSTALL_SERVICE_NAME="icewarp"

SETUP_SERVER_CONF="$EMPTY_VALUE"
SETUP_SERVER_CONF_EXISTING="$EMPTY_VALUE"

SETUP_CONFIG_FILE_EXISTS="0"

INSTALL_LOG=~/icewarp-install.log
INSTALL_ERROR_LOG=~/icewarp-install-error.log

RUNNING_UID=$(id -u)

UPGRADE="0"
KILL_SERVICES="0"
CONVERSION_DOC_PDF="1"
CONVERSION_PDF_IMAGE="1"


OS_DIST="$EMPTY_VALUE"
OS_PLATFORM="$EMPTY_VALUE"

POSTMASTER_ALIASES="postmaster;admin;administrator;supervisor;hostmaster;webmaster;abuse"

HELPER_WIZARD_FILE="/tmp/iwwizlog"

# cmdline flags
OPT_FAST_INSTALL_MODE="0"
OPT_ALLOW_MISSING_ARCHITECTURE="0"
OPT_AUTO="0"
OPT_INSTALL_DIR=""
OPT_USER=""
OPT_LICENSE=""

# platform specific declarations
source $(dirname $0)"/platform"

# init

SELF=$0
WORKDIR=$(dirname $0)
LIBLIST32=""
LIBLIST64=""

if [ "$TERM" == "xterm" ] || [ "$TERM" == "xterm-color" ] || [ "$TERM" == "screen" ]; then
    GOOD=$'\e[0;40;32m'
    BAD=$'\e[0;40;31m'
    NORMAL=$'\e[0m'
    WARN=$'\e[0;40;93m'
    HILITE=$'\e[0;40;97m'
    BRACKET=$'\e[0;40;39m'
else
    GOOD=$'\e[0;40;32m'
    BAD=$'\e[0;40;31m'
    NORMAL=$'\e[0m'
    WARN=$'\e[0;40;33m'
    HILITE='\e[4;40;30m'
    BRACKET=${NORMAL}
fi

good()
{
    echo -e "${GOOD}**${NORMAL}\t$*"
}

bad()
{
    echo -e "${BAD}**${NORMAL}\tError: $*"
}

warn()
{
    echo -e "${WARN}**${NORMAL}\tWarning: $*"
}

hilite()
{
    echo -e "${GOOD}**${HILITE}\t$*${NORMAL}"
}

getparam()
{
    echo -e -n "${GOOD}**${NORMAL}\t$1 [$2]${NORMAL}: "
    read PARAM
}

getpassword()
{
    echo -e -n "${GOOD}**${NORMAL}\t$1${NORMAL}: "
    read -s PARAM
    echo ""
}

copy_if_not_exists()
{
    if ! [ -f "$2" ]; then
        cp -f "$1" "$2"
    fi
}

# calls tool and returns single value of single api variable
# IWS_INSTALL_DIR have to be set
# params: object variable
get_liccheck_variable()
{
    CMD_STDOUT=$("${WORKDIR}/liccheck.sh" get "$1" "$2" | sed 's/^[^:]*: //')
    CMD_RET=$?
    echo "${CMD_STDOUT}"
    return ${CMD_RET}
}

get_api_variable()
{
    CMD_STDOUT=$("${SETUP_INSTALL_DIR}/tool.sh" get "$1" "$2" | sed 's/^[^:]*: //')
    CMD_RET=$?
    echo "${CMD_STDOUT}"
    return ${CMD_RET}
}

# $1 - version (number only)
# $2 - respect build number flag, 0 == true
version_to_num()
{
    NUM=$(cut -f1 -d. <<< $1)
    if [ "x${NUM}" == "x" ]; then
        NUM=0
    fi
    MAJOR=$(($NUM * 1000000000000))

    NUM=$(cut -f2 -d. <<< $1)
    if [ "x${NUM}" == "x" ]; then
        NUM=0
    fi
    MIDDLE=$(($NUM * 10000000000))

    NUM=$(cut -f3 -d. <<< $1)
    NUM1=$(cut -f1 -d- <<< $NUM)
    if [ "x${NUM1}" == "x" ]; then
        NUM1=0
    fi
    MINOR1=$(($NUM1 * 100000000))

    NUM2=$(cut -f2 -d- <<< $NUM)
    if [ "x${NUM2}" == "x" ]; then
        NUM2=0
    fi
    MINOR2=$(($NUM2 * 1000000))

    if $2; then
        NUM=$(cut -f4 -d. <<< $1)
        if [ "x${NUM}" == "x" ]; then
            NUM=0
        fi
        BUILD=$NUM
    else
        BUILD=0
    fi
    
    RESULT=$(($MAJOR + $MIDDLE + $MINOR1 + $MINOR2 + $BUILD))
}

# IceWarp version string comparator
# $1, $2 version
# $3 - compareNB, 0 == true
# $4 - RespectBuildNumber, 0 == true
# returns: negative - $1 > $2, 0 - $1 == $2, positive - $1 < $2 
compare_version()
{
    VERSION_1="$1"
    VERSION_2="$2"
    COMPARE_NB=$3
    RESPECT_BUILD_NUMBER=$4

    # At first compare version numbers
    PURE_VERSION_1=$(cut -f1 -d' ' <<< $VERSION_1)
    version_to_num $PURE_VERSION_1 $RESPECT_BUILD_NUMBER
    NUM_VERSION_1=$RESULT

    PURE_VERSION_2=$(cut -f1 -d' ' <<< $VERSION_2)
    version_to_num $PURE_VERSION_2 $RESPECT_BUILD_NUMBER
    NUM_VERSION_2=$RESULT

    if $COMPARE_NB && [ $NUM_VERSION_1 = $NUM_VERSION_2 ]; then
        # Compare NB, RC
        # Get NB part
        NB_VERSION_1=$(cut -f2 -d' ' <<< $VERSION_1)
        NB_VERSION_2=$(cut -f2 -d' ' <<< $VERSION_2)
        
        # Check if RC
        RC=$(echo ${NB_VERSION_1:0:2} | tr 'a-z' 'A-Z')
        if [ "${RC}" == "RC" ]; then
            RC_1=true
        else
            RC_1=false
        fi

        RC=$(echo ${NB_VERSION_2:0:2} | tr 'a-z' 'A-Z')
        if [ "${RC}" == "RC" ]; then
            RC_2=true
        else
            RC_2=false
        fi

        # Check if NB
        if [ ${NB_VERSION_1:0:1} == "(" ]; then
            NB_1=true
        else
            NB_1=false
        fi

        if [ ${NB_VERSION_2:0:1} == "(" ]; then
            NB_2=true
        else
            NB_2=false
        fi

        if ! $RC_1 && ! $NB_1; then
            NB_VERSION_1=""
        fi

        if ! $RC_2 && ! $NB_2; then
            NB_VERSION_2=""
        fi

        # evaluate
        if [ "x${NB_VERSION_1}" == "x" ]; then
            if [ "x${NB_VERSION_2}" == "x" ]; then
                # Both wihtout RC or NB
                RESULT=0
            else
                # 1 is release, 2 NB or RC
                RESULT=-1
            fi
        elif [ "x${NB_VERSION_2}" == "x" ]; then
            # 1 is NB or RC, 2 is release
            RESULT=1
        else
            # Both are NB or RC
            if [ $RC_1 != $RC_2 ]; then
                # RC is greater than NB
                if $RC_1; then
                    RESULT=-1
                else
                    RESULT=1
                fi
            else
                # either both NB, or Both RC
                if $NB_1; then
                    # both NB, use lexicographical sorting
                    if [ "${NB_VERSION_1}" == "${NB_VERSION_2}" ]; then
                        RESULT=0
                    elif [[ "${NB_VERSION_1}" < "${NB_VERSION_2}" ]]; then
                        RESULT=1
                    else
                        RESULT=-1
                    fi
                else
                    # Both RC, we have to parse exactly the rc number
                    RC_NUM_1=${NB_VERSION_1:2}
                    RC_NUM_2=${NB_VERSION_2:2}

                    RESULT=$(($RC_NUM_2 - $RC_NUM_1))
                fi
            fi
        fi
    else
        RESULT=$(($NUM_VERSION_2 - $NUM_VERSION_1))
    fi
}

# Scans system for available shared libraries
build_dynamic_modules_list()
{
    # Refresh ld cache
    ldconfig
    LIBLIST32=""
    LIBLIST64=""
    LIBLIST32=$(ldconfig -p | grep libc6 | grep -v "x86-64" | sed 's/[[:space:]]*//' | sed 's/ (.*//' | while read LINE; do
        echo -n " ${LINE}"
    done)

    if [ "${SETUP_SERVER_PLATFORM}" == "x86_64" ]; then
        LIBLIST64=$(ldconfig -p | grep "x86-64" | sed 's/[[:space:]]*//' | sed 's/ (.*//' | while read LINE; do
           echo -n " ${LINE}"
        done)
    fi
}

# Checks, if given dynamic 32-bit library is available on system
# Params: filename
check_dynamic_module_32()
{
    grep "$1" <<< "${LIBLIST32}" &>/dev/null
}

# Checks, if given dynamic 64-bit library is available on system
# Params: filename
check_dynamic_module_64()
{
    grep "$1" <<< "${LIBLIST64}" &>/dev/null
}

# Sets variables depending on command line flags
parse_cmdline()
{
    while [ "x$1" != "x" ]; do
        case `echo $1 | tr a-z A-Z` in
            -F|--FAST)
                OPT_FAST_INSTALL_MODE="1"
                ;;
            --ALLOW-MISSING-ARCHITECTURE)
                OPT_ALLOW_MISSING_ARCHITECTURE="1"
                ;;
            -A|--AUTO)
                OPT_AUTO="1"
                ;;
            --INSTALL-DIR)
                OPT_INSTALL_DIR="$2"
                shift
                ;;
            --USER)
                OPT_USER="$2"
                shift
                ;;
            --LICENSE)
                OPT_LICENSE="$2"
                shift
                ;;
        esac
        shift
    done
}

# Checks, if OSDIST was detected as expected
test_correct_osdist()
{
    MATCH=false
    for DISTRO in "${PLATFORM_OSDIST[@]}"; do
        if [ "${DISTRO}" == "${OS_DIST}" ]; then
            MATCH=true
            break
        fi
    done

    if ! $MATCH; then
        bad "Incompatible Linux distribution"
        bad "This install script have to be run on ${PLATFORM_NAME}"
        exit 1
    fi
}

# Checks, if install script runs on correct platform and version
test_correct_platform()
{
    WARN_LEVEL=0

    if platform_get_distro_id; then
        MATCH=false
        for DISTRO in "${PLATFORM_DISTRO_IDS[@]}"; do
            if [ "${DISTRO}" == "${PLATFORM_RESULT}" ]; then
                MATCH=true
                break
            fi
        done

        if ! $MATCH; then
            WARN_LEVEL=2
        fi
    else
        WARN_LEVEL=1
    fi

    if [ $WARN_LEVEL -eq 0 ]; then
        if platform_get_distro_major_version; then
            MATCH=false
            for VERSION in "${PLATFORM_VERSIONS[@]}"; do
                if [ "${VERSION}" == "${PLATFORM_RESULT}" ]; then
                    MATCH=true
                    break
                fi
            done

            if ! $MATCH; then
                WARN_LEVEL=2
            fi
        else
            WARN_LEVEL=1
        fi
    fi
    
    if [ $WARN_LEVEL -eq 0 ]; then
        if platform_get_hw_platform; then
            MATCH=false
            for PLATFORM in "${PLATFORM_HW_PLATFORMS[@]}"; do
                if [ "${PLATFORM}" == "${PLATFORM_RESULT}" ]; then
                    MATCH=true
                    break
                fi
            done

            if ! $MATCH; then
                WARN_LEVEL=3
            fi
        else
            WARN_LEVEL=1
        fi
    fi

    case $WARN_LEVEL in
        1)  warn "Cannot check, if this package is compatible with the system"
            if [ "${OPT_AUTO}" != "1" ]; then
                ask_with_confirmation "Are you sure you are installing on ${PLATFORM_NAME}?" "N" "y"
                if [ $? -ne 2 ]; then
                    bad "Installation aborted on user request."
                    exit 1
                fi
            else
                echo "Automatic installation mode - expecting that package is compatible"
            fi
            ;;
        2)  bad "Incompatible Linux distribution"
            bad "This install script has to be run on ${PLATFORM_NAME}"
            exit 1 
            ;;
        3)  bad "Incompatible Linux distribution"
            bad "This install script has to be run on ${PLATFORM_NAME}"
            bad "You are probably trying to install 64bit IceWarp Server on 32bit machine."
            exit 1 
    esac
}

# Checks if selinux is active, if so, warns user
test_selinux()
{
    SELINUX=$(getenforce 2>/dev/null)
    if grep "Enforcing" <<< ${SELINUX} &>/dev/null; then
        echo ""
        warn "SELinux is in enforcing mode on this system.
                 Please put SELinux into permissive or disabled mode
                 or follow the guide in Icewarp Installation and Control on Linux document.

                 Press ENTER to continue or Ctrl-C to exit setup"
        if [ "${OPT_AUTO}" != "1" ]; then
            read -s
            echo ""
        else
            echo "Automatic installation mode - ignoring SELinux warning"
        fi
    fi
}

# Does some platform specific checks, like RHEL6 pam module being up to date
test_platform_specifics()
{
    if ! platform_do_specific_checks; then
        exit 1
    fi
}

# Tests for dependencies, offers its installation
test_dependencies()
{
    MISSING_LIBRARIES32=""
    MISSING_LIBRARIES64=""
    MISSING_PACKAGES=""

    MISSING_PACKAGES="x"
    FIRST_PASS=0
    while [ "x${MISSING_PACKAGES}" != "x" ]; do
        MISSING_LIBRARIES32=""
        MISSING_LIBRARIES64=""
        MISSING_PACKAGES=""
        good "Checking dynamic library dependencies..."

        # Check for dependencies
        build_dynamic_modules_list

        # 32 bit libraries
        for I in $(seq 1 ${#PLATFORM_DEPENDENCIES32[*]}); do
            LIBRARY=${PLATFORM_DEPENDENCIES32[$I]}
            PACKAGE=${PLATFORM_PACKAGES32[$I]}
            # Obtain package for 32/64 bit platform if differs
            if grep "/" <<< "${PACKAGE}" &>/dev/null; then
                if [ "${OS_PLATFORM}" == "x86_64" ]; then
                    PACKAGE=$(sed 's:^.*/::' <<< "${PACKAGE}")
                else
                    PACKAGE=$(sed 's:/.*$::' <<< "${PACKAGE}")
                fi
            fi

            # Some 32 bit packages on 64 bit system are unavailable - they are distributed with IWS
            if [ "x${PACKAGE}" != "x" ]; then
                if ! check_dynamic_module_32 "${LIBRARY}"; then
                    MISSING_LIBRARIES32="${MISSING_LIBRARIES32} ${LIBRARY}"
                    MISSING_PACKAGES="${MISSING_PACKAGES}\n${PACKAGE}"
                fi
            fi
        done

        if [ "${SETUP_SERVER_PLATFORM}" == "x86_64" ]; then
            # 64 bit libraries
            for I in $(seq 1 ${#PLATFORM_DEPENDENCIES64[*]}); do
                LIBRARY=${PLATFORM_DEPENDENCIES64[$I]}
                PACKAGE=${PLATFORM_PACKAGES64[$I]}
                if ! check_dynamic_module_64 "${LIBRARY}"; then
                    MISSING_LIBRARIES64="${MISSING_LIBRARIES64} ${LIBRARY}"
                    MISSING_PACKAGES="${MISSING_PACKAGES}\n${PACKAGE}"
                fi
            done
        fi

        if [ "x${MISSING_PACKAGES}" != "x" ]; then
            # Warn if this is not first pass - something went wrong with installation
            if [ ${FIRST_PASS} -ne 0 ]; then
                echo ""
                warn "All required dependencies are still not satisfied,
             probably the installation of them failed or was interrupted.
             
             Updating your system may help.
             
             Press ENTER to continue or Ctrl-C to exit setup"
                if [ "${OPT_AUTO}" != "1" ]; then
                    read -s
                    echo ""
                else
                    bad "Automatic installation mode - dependencies not installed, exiting"
                    exit 2
                fi
            fi

            FIRST_PASS=1
            # Strip duplicates, convert to space separated list
            MISSING_PACKAGES=$(echo -e ${MISSING_PACKAGES} | sort | uniq | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')

            warn "Some of the libraries required by IceWarp server were not found on this system."
            echo ""
            if [ "x${MISSING_LIBRARIES32}" != "x" ]; then
                echo "        Missing 32-bit libraries:${MISSING_LIBRARIES32}"
                echo ""
            fi
            if [ "x${MISSING_LIBRARIES64}" != "x" ]; then
                echo "        Missing 64-bit libraries:${MISSING_LIBRARIES64}"
                echo ""
            fi
            echo "        These packages should be installed to satisfy the dependencies:
   ${MISSING_PACKAGES}"
            echo ""
            if [ "${OPT_AUTO}" != "1" ]; then
                ask_with_confirmation "Do you want to install these packages into the system?" "Y" "n"
                if [ $? -eq 1 ]; then
                    platform_install_packages "0" $MISSING_PACKAGES 
                else
                    echo ""
                    warn "IceWarp server won't work without these libraries
                 Press ENTER to continue or Ctrl-C to exit setup"
                    read -s
                    echo ""
                    break
                fi
            else
                good "Automatic installation mode - installing missing dependencies"
                platform_install_packages "1" $MISSING_PACKAGES 
            fi
        fi
        echo ""
    done
}

# Tests if programs needed to install
test_program_servicemanagement()
{
    while ! platform_check_service_management_tool; do
        bad "Program ${PLATFORM_SERVICE_MANAGEMENT_TOOL_NAME} seems not to be installed."
        if platform_is_install_service_management_tool_supported; then
            if [ "${OPT_AUTO}" != "1" ]; then
                ask_with_confirmation "Do you want to install it now into the system?" "Y" "n"
                if [ $? -eq 1 ]; then
                    platform_install_service_management_tool "0"
                else
                    bad "IceWarp server cannot be installed without ${PLATFORM_SERVICE_MANAGEMENT_TOOL_NAME}"
                    exit 1
                fi
            else
                good "Automatic installation mode - installing ${PLATFORM_SERVICE_MANAGEMENT_TOOL_NAME}"
                platform_install_service_management_tool "1"

                if ! platform_check_service_management_tool; then
                    bad "Automatic installation mode - cannot install ${PLATFORM_SERVICE_MANAGEMENT_TOOL_NAME}"
                    exit 2
                fi
            fi
        else
            bad "Please install ${PLATFORM_SERVICE_MANAGEMENT_TOOL_NAME} manually, it cannot be done by this script"
            exit 1
        fi
    done
}

test_program_sed()
{
    sed --version &> /dev/null
    if [ $? -ne 0 ]; then
        bad "Error testing sed. Program sed seems not to be installed."
        exit 1
    fi
}

test_program_unzip()
{
    # check unzip
    unzip -h &> /dev/null
    while [ $? -ne 0 ]; do
        bad "Program unzip seems not to be installed."
        if [ "${OPT_AUTO}" != "1" ]; then
            ask_with_confirmation "Do you want to install it into the system?" "Y" "n"
            if [ $? -eq 1 ]; then
                platform_install_unzip "0"
            else
                bad "IceWarp server cannot be installed without unzip"
                exit 1
            fi
        else
            good "Automatic installation mode - installing unzip utility"
            platform_install_unzip "1"

            unzip -h &> /dev/null
            if [ $? -ne 0 ]; then
                bad "Automatic installation mode - cannot install unzip"
                exit 2
            fi
        fi
        unzip -h &> /dev/null
    done
}

check_documentpreview_programs_presence()
{
    # check office and gs - if present
    if [ "x${PLATFORM_LIBREOFFICE_WRITER_PACKAGE}" != "x" ]; then
        (cd / && which ${PLATFORM_LIBREOFFICE_WRITER_BINARY} &> /dev/null)
        LIBREOFFICE_WRITER=$?
    else
        LIBREOFFICE_WRITER=0
    fi

    if [ "x${PLATFORM_LIBREOFFICE_CALC_PACKAGE}" != "x" ]; then
        (cd / && which ${PLATFORM_LIBREOFFICE_CALC_BINARY} &> /dev/null)
        LIBREOFFICE_CALC=$?
    else
        LIBREOFFICE_CALC=0
    fi

    if [ "x${PLATFORM_LIBREOFFICE_IMPRESS_PACKAGE}" != "x" ]; then
        (cd / && which ${PLATFORM_LIBREOFFICE_IMPRESS_BINARY} &> /dev/null)
        LIBREOFFICE_IMPRESS=$?
    else
        LIBREOFFICE_IMPRESS=0
    fi

    if [ "x${PLATFORM_LIBREOFFICE_HEADLESS_PACKAGE}" != "x" ] && ! [ -f "${PLATFORM_LIBREOFFICE_HEADLESS_FILE}" ]; then
        LIBREOFFICE_HEADLESS=1
    else
        LIBREOFFICE_HEADLESS=0
    fi

    if [ ${LIBREOFFICE_HEADLESS} -eq 1 ] && [ "x${PLATFORM_LIBREOFFICE_HEADLESS_PACKAGE}" != "x" ] && [ "x${PLATFORM_LIBREOFFICE_HEADLESS_FILE2}" != "x" ] && [ -f "${PLATFORM_LIBREOFFICE_HEADLESS_FILE2}" ]; then
        LIBREOFFICE_HEADLESS=0
    fi

    (cd / && gs --version &> /dev/null)
    GHOSTSCRIPT=$?
}

check_libreoffice_programs_solved()
{
    if [ ${LIBREOFFICE_WRITER} -ne 0 ] || [ ${LIBREOFFICE_CALC} -ne 0 ] || [ ${LIBREOFFICE_IMPRESS} -ne 0 ] || [ ${LIBREOFFICE_HEADLESS} -ne 0 ]; then
        return 1
    else
        return 0
    fi
}

test_program_documentpreview()
{
    check_documentpreview_programs_presence

    while ! check_libreoffice_programs_solved || [ ${GHOSTSCRIPT} -ne 0 ]; do
        MISSING_TEXT=""
        MISSING_PACKAGES=""
        if [ ${LIBREOFFICE_WRITER} -ne 0 ]; then
            MISSING_TEXT="${PLATFORM_LIBREOFFICE_WRITER_PACKAGE}"
            MISSING_PACKAGES="${PLATFORM_LIBREOFFICE_WRITER_PACKAGE}"
        fi

        if [ ${LIBREOFFICE_CALC} -ne 0 ]; then
            if [ "x${MISSING_TEXT}" != "x" ]; then
                MISSING_TEXT="${MISSING_TEXT}, "
                MISSING_PACKAGES="${MISSING_PACKAGES} "
            fi
            MISSING_TEXT="${MISSING_TEXT}${PLATFORM_LIBREOFFICE_CALC_PACKAGE}"
            MISSING_PACKAGES="${MISSING_PACKAGES}${PLATFORM_LIBREOFFICE_CALC_PACKAGE}"
        fi

        if [ ${LIBREOFFICE_IMPRESS} -ne 0 ]; then
            if [ "x${MISSING_TEXT}" != "x" ]; then
                MISSING_TEXT="${MISSING_TEXT}, "
                MISSING_PACKAGES="${MISSING_PACKAGES} "
            fi
            MISSING_TEXT="${MISSING_TEXT}${PLATFORM_LIBREOFFICE_IMPRESS_PACKAGE}"
            MISSING_PACKAGES="${MISSING_PACKAGES}${PLATFORM_LIBREOFFICE_IMPRESS_PACKAGE}"
        fi

        if [ ${LIBREOFFICE_HEADLESS} -ne 0 ]; then
            if [ "x${MISSING_TEXT}" != "x" ]; then
                MISSING_TEXT="${MISSING_TEXT}, "
                MISSING_PACKAGES="${MISSING_PACKAGES} "
            fi
            MISSING_TEXT="${MISSING_TEXT}${PLATFORM_LIBREOFFICE_HEADLESS_PACKAGE}"
            MISSING_PACKAGES="${MISSING_PACKAGES}${PLATFORM_LIBREOFFICE_HEADLESS_PACKAGE}"
        fi

        if [ ${GHOSTSCRIPT} -ne 0 ]; then
            if [ "x${MISSING_TEXT}" != "x" ]; then
                MISSING_TEXT="${MISSING_TEXT} and "
                MISSING_PACKAGES="${MISSING_PACKAGES} "
            fi

            MISSING_TEXT="${MISSING_TEXT}${PLATFORM_GHOSTSCRIPT_PACKAGE}"
            MISSING_PACKAGES="${MISSING_PACKAGES}${PLATFORM_GHOSTSCRIPT_PACKAGE}"
        fi

        warn "Tools needed for WebDocuments are not installed."
        echo ""
        if [ "${OPT_AUTO}" != "1" ]; then
            ask_with_confirmation "Do you want to install ${MISSING_TEXT} into the system?" "Y" "n"
            if [ $? -eq 1 ]; then
                platform_install_packages "0" ${MISSING_PACKAGES} 
            else
                echo ""
                warn "Press ENTER to continue without WebDocuments, CTRL+C to quit"
                read -s
                echo ""
                break
            fi
        else
            good "Automatic installation mode - installing ${MISSING_TEXT}."
            platform_install_packages "1" ${MISSING_PACKAGES} 

            check_documentpreview_programs_presence
            if ! check_libreoffice_programs_solved || [ ${GHOSTSCRIPT} -ne 0 ]; then
                bad "Automatic installation mode - cannot install WebDocuments tools."
                exit 2
            fi
        fi
       
        check_documentpreview_programs_presence

        if ! check_libreoffice_programs_solved; then
            platform_warn_about_rhel_repos
        fi
    done

    if ! platform_is_install_libreoffice_supported || ! check_libreoffice_programs_solved; then
        CONVERSION_DOC_PDF="0"
    fi

    if [ ${GHOSTSCRIPT} -ne 0 ]; then
        CONVERSION_PDF_IMAGE="0"
    fi
}

check_conferencing_programs_presence()
{
    # check java and lame - if present
    (cd / && java -version &> /dev/null)
    JAVA=$?

    (cd / && lame --help &> /dev/null)
    LAME=$?
}

test_program_conferencing()
{
    # check java - if present
    check_conferencing_programs_presence

    # We distribute lame on platforms where lame is not in default repo
    if [ ${LAME} -ne 0 ] && [ "x${PLATFORM_LAME_PACKAGE}" == "x" ]; then
        LAME=0
    fi

    while [ ${JAVA} -ne 0 ] || [ ${LAME} -ne 0 ]; do
        MISSING_TEXT=""
        MISSING_PACKAGES=""
        if [ ${JAVA} -ne 0 ]; then
            MISSING_TEXT="${PLATFORM_JAVA_NAME}"
            MISSING_PACKAGES="${PLATFORM_JAVA_PACKAGE_NAME}"
        fi

        if [ ${LAME} -ne 0 ]; then
            if [ "x${MISSING_TEXT}" != "x" ]; then
                MISSING_TEXT="${MISSING_TEXT} and "
                MISSING_PACKAGES="${MISSING_PACKAGES} "
            fi

            MISSING_TEXT="${MISSING_TEXT}${PLATFORM_LAME_PACKAGE}"
            MISSING_PACKAGES="${MISSING_PACKAGES}${PLATFORM_LAME_PACKAGE}"
        fi

        warn "Tools needed for WebMeetings, auto attendant and echo service are not installed."
        echo ""
        if [ "${OPT_AUTO}" != "1" ]; then
            ask_with_confirmation "Do you want to install ${MISSING_TEXT} into the system?" "Y" "n"
            if [ $? -eq 1 ]; then
                platform_install_packages "0" ${MISSING_PACKAGES} 
            else
                echo ""
                warn "Press ENTER to continue without voice services, CTRL+C to quit"
                read -s
                echo ""
                break
            fi
        else
            good "Automatic installation mode - installing ${MISSING_TEXT}."
            platform_install_packages "1" ${MISSING_PACKAGES} 

            check_conferencing_programs_presence
            if [ ${JAVA} -ne 0 ] || [ ${LAME} -ne 0 ]; then
                bad "Automatic installation mode - cannot install voice services tools."
                exit 2
            fi
        fi
        check_conferencing_programs_presence

        if [ "x${PLATFORM_LAME_PACKAGE}" == "x" ]; then
            LAME=0
        fi
    done

    # check java version, must be at least 1.6
    java -version &> /dev/null
    if [ $? -eq 0 ]; then
        JAVA_VERSION=$(java -version 2>&1 | grep "java version")
        JAVA_VERSION_MAJOR=$(sed 's/.*\"\([^\.]\+\).*\"$/\1/' <<< ${JAVA_VERSION})
        JAVA_VERSION_MINOR=$(sed 's/.*\"[^\.]\+\.\([^\.]\+\).*\"$/\1/' <<< ${JAVA_VERSION})
        if [ ${JAVA_VERSION_MAJOR} -eq 1 ] && [ ${JAVA_VERSION_MINOR} -lt 6 ]; then
            warn "Detected java version ${JAVA_VERSION_MAJOR}.${JAVA_VERSION_MINOR}"
            echo "        IceWarp WebMeetings, auto attendand and echo service needs at least java of version 1.6"
            echo ""
            echo "        Press ENTER to continue or CTRL+C to quit"
            if [ "${OPT_AUTO}" != "1" ]; then 
                read -s
                echo ""
            else
                bad "Automatic installation mode - bad java version."
                exit 2
            fi
        fi
    fi
}

test_programs()
{
    test_program_servicemanagement
    test_program_sed
    test_program_unzip
    test_program_documentpreview
    test_program_conferencing
}


# Detection of host OS distribution
# Function tryes to detect OS in simple way
# Result of detection is:
# - "UNKNOWN" if distributionplatform is not known
# - "RHEL" if OS is Red Hat Enterprise Linux
detect_os_distribution()
{
    OS_DIST="UNKNOWN"
    OS_PLATFORM="UNKNOWN"

    if [ -f "/etc/redhat-release" ]; then
        OS_DIST="RHEL"
    fi
    if [ -f "/etc/debian_version" ]; then
        OS_DIST="DEB"
    fi
    if [ -f "/etc/arch-release" ]; then
        OS_DIST="ARCH"
    fi
    if [ "$OS_DIST" == "UNKNOWN" ]; then
        bad "Unknown Linux distribution"
        exit 1
    fi

    OS_PLATFORM=$(uname -m)
}

# Ask question with confirmation
# Parameters:
# $1 - question
# $2 - first choice, it is choosed if user enters only empty string
# $3 - second choice, $4 third choice...
# Return:
# 0 on error - unknown string entered
# 1 if first choice was selected
# 2 if second choice was selected
# 3 if third choice...
ask_with_confirmation()
{
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        return 0
    fi
    LOWER_CHOICE_1=$(echo "$2" | tr "A-Z" "a-z")
    LOWER_CHOICE_2=$(echo "$3" | tr "A-Z" "a-z")

    # make options string
    local OPTIONS="${GOOD}**${NORMAL}\t${1} ${BRACKET}[${HILITE}${2}${NORMAL}"
    for ARG in "${@:3}"; do 
        OPTIONS+="/${ARG}"
    done
 
    echo -e -n "${OPTIONS}${BRACKET}]${NORMAL}: "
    read PARAM
    if [ -z "$PARAM" ]; then 
        return 1
    fi

    PARAM=$(echo "$PARAM" | tr "A-Z" "a-z")
    declare -i I=1
    for ARG in "${@:2}"; do  # arguments 2 through n (i.e. 3 args starting at number 2)
        local LOWER_CHOICE=$(echo "$ARG" | tr "A-Z" "a-z")
        if [ "$PARAM" == "$LOWER_CHOICE" ]; then
            return $I
        fi
        ((I++))
    done

    return 0
}

preconf()
{
    # reset variables for old configuration
    InstallDir=""
    User=""
    Version=""

    if [ -f "$1" ]; then
        source "$1"

        # check for new variables first

        # check for install dir
        if [ "x${IWS_INSTALL_DIR}" != "x" ]; then
            SETUP_INSTALL_DIR="$IWS_INSTALL_DIR"
        fi

        # check for install user
        if [ "x${IWS_PROCESS_USER}" != "x" ]; then
            SETUP_INSTALL_USER="$IWS_PROCESS_USER"
        fi

        # check for installed version
        if [ "x${IWS_VERSION}" != "x" ]; then
            SETUP_OLDVERSION="$IWS_VERSION"
        fi

        # check for installed platform
        if [ "x${IWS_PLATFORM}" != "x" ]; then
            SETUP_SERVER_OLDPLATFORM="${IWS_PLATFORM}"
        fi

        # check for old variables

        # check for install dir
        if [ "x${InstallDir}" != "x" ]; then
            SETUP_INSTALL_DIR="$InstallDir"
        fi

        if [ "x${User}" != "x" ]; then
            SETUP_INSTALL_USER="$User"
        fi

        if [ "x${Version}" != "x" ]; then
            SETUP_OLDVERSION="$Version"
        fi
    fi
}

# Function displays license file and waits until user press [ENTER]
accept_license()
{
    less "${WORKDIR}/LICENSE"
    echo ""
    good "You must accept this license agreement if you want to continue."
    good "Press ENTER to accept license or CTRL+C to quit"
    if [ "${OPT_AUTO}" != "1" ]; then
        read -s
        echo ""
    else
        good "Automatic installation mode - license accepted."
    fi
    echo ""
}

# Displayes information about stdout log and stderr log placement
display_log_info()
{
    good "Installer log is available in ${INSTALL_LOG}"
    good "Installer error log is available in ${INSTALL_ERROR_LOG}"
    good ""
}

# Function checks if configuration file exists and sets variables
# Parameters
#  $1 - full path to assumed configuration file
# Returns:
#  0 - if all variables SETUP_INSTALL_DIR, SETUP_INSTALL_USER are detected
# != 0 - if some of variables or non of variables SETUP_INSTALL_DIR, SETUP_INSTALL_USER are detected
detect_install_options_sub()
{
    CONFIG_FILE="$1"

    # for safety initialize variables
    SETUP_INSTALL_DIR="$EMPTY_VALUE"
    SETUP_INSTALL_USER="$EMPTY_VALUE"
    SETUP_OLDVERSION="$EMPTY_VALUE"
    SETUP_SERVER_OLDPLATFORM="${EMPTY_VALUE}"

    if [ -f "$CONFIG_FILE" ]; then
        preconf "$CONFIG_FILE"
        # check for set values
        if [ "x${SETUP_INSTALL_DIR}" != "x${EMPTY_VALUE}" ] &&
           [ "x${SETUP_INSTALL_USER}" != "x${EMPTY_VALUE}" ] &&
           [ "x${SETUP_OLDVERSION}" != "x${EMPTY_VALUE}" ]; then
           # all values was set
           return 0
        fi
    fi

    # configuration file not found, or some values was not set
    # reset variables
    SETUP_INSTALL_DIR="$EMPTY_VALUE"
    SETUP_INSTALL_USER="$EMPTY_VALUE"
    SETUP_OLDVERSION="$EMPTY_VALUE"
    SETUP_SERVER_OLDPLATFORM="${EMPTY_VALUE}"
    return 1
}

# Function detects install options entered by user from already installed server
# If variables are not detected, then default values are set
# Load balanced setup is not detected here, because for detecting load balanced setup tool needs to be called,
# so server configuration file must be created first.
# If configuration file is found, flag SETUP_CONFIG_FILE_EXISTS is set to value other than 0
# Variables detected:
# 1. install dir default - SETUP_INSTALL_DIR_DEFAULT
# 2. install user - SETUP_INSTALL_USER
# returns:
# always 0, if install options are not detected they are set to default values
detect_install_options()
{
    # detect configuration files from newest to oldest,
    # Merak 9.4 upgraded to IceWarp Server 10 can be already installed or
    # clean IceWarp Server 10 can be already installed

    # assume configuration file exists
    SETUP_CONFIG_FILE_EXISTS="1"

    detect_install_options_sub "/etc/icewarp/icewarp.conf"
    if [ $? -eq 0 ]; then
        return 0
    fi

    # directory /opt/icewarp

    # IceWarp Server 10
    detect_install_options_sub "/opt/icewarp/config/icewarp.conf"
    if [ $? -eq 0 ]; then
        return 0
    fi

    # Merak 9.4
    detect_install_options_sub "/opt/icewarp/config/merak.conf"
    if [ $? -eq 0 ]; then
        return 0
    fi

    # directory /opt/merak
    
    # IceWarp Server 10
    detect_install_options_sub "/opt/merak/config/icewarp.conf"
    if [ $? -eq 0 ]; then
        return 0
    fi

    # Merak 9.4
    detect_install_options_sub "/opt/merak/config/merak.conf"
    if [ $? -eq 0 ]; then
        return 0
    fi

    # set default values
    if [ "x${OPT_INSTALL_DIR}" == "x" ]; then
        SETUP_INSTALL_DIR="$SETUP_INSTALL_DIR_DEFAULT"
    else
        SETUP_INSTALL_DIR="${OPT_INSTALL_DIR}"
    fi

    if [ "x${OPT_USER}" == "x" ]; then
        SETUP_INSTALL_USER="$SETUP_INSTALL_USER_DEFAULT"
    else
        SETUP_INSTALL_USER="${OPT_USER}"
    fi

    # configuration file not found
    SETUP_CONFIG_FILE_EXISTS="0"

    return 1
}

# If previous installation is detected, function checks if it is not newer or if 32bit is not replacing 64bit
test_unwanted_downgrade()
{
    if [ -d "$SETUP_INSTALL_DIR" -a "$SETUP_CONFIG_FILE_EXISTS" != "0" ]; then
        # check downgrade
        compare_version "${SETUP_OLDVERSION}" "${SETUP_NEWVERSION}" true true
        if [ $RESULT -lt 0 ]; then
            echo ""
            warn "You are trying to downgrade IceWarp Server from version ${SETUP_OLDVERSION} to ${SETUP_NEWVERSION}."
            echo "        Note that downgrade is unsupported and can lead to irreversible corruption of the server."
            echo "        Do you want to continue?"
            echo ""
            echo "        Press ENTER to continue, CTRL+C to quit"
            if [ "${OPT_AUTO}" != "1" ]; then
                read -s
                echo ""
            else
                good "Automatic installation mode - downgrade confirmed."
            fi
        fi

        # check bitness conflict
        if [ "${SETUP_SERVER_OLDPLATFORM}" == "x86_64" ] && [ "${SETUP_SERVER_PLATFORM}" != "x86_64" ]; then
            echo ""
            warn "You are trying to install 32bit IceWarp Server over existing 64bit installation."
            echo "        Do you want to continue?"
            echo ""
            echo "        Press ENTER to continue, CTRL+C to quit"
            if [ "${OPT_AUTO}" != "1" ]; then
                read -s
                echo ""
            else
                good "Automatic installation mode - upgrading 64bit to 32bit confirmed."
            fi
        fi

    fi
}

# Function displays questions about SETUP_INSTALL_DIR, SETUP_INSTALL_USER
# Function detect_install_options() must be called first
# returns:
#  no return
ask_questions()
{
    # check for "new installation" or "upgrade"
    # check if detected installation directory exists
    if [ -d "$SETUP_INSTALL_DIR" -a "$SETUP_CONFIG_FILE_EXISTS" != "0" ]; then
        good "Previous IceWarp server installation detected."
        good "Installation directory was set to ${SETUP_INSTALL_DIR}."
        if [ "${OPT_AUTO}" != "1" ]; then
            ask_with_confirmation "Do you want to upgrade?" "Y" "n"
            if [ $? -eq 1 ]; then
                UPGRADE="1"
            else
                UPGRADE="0"
            fi
        else
            good "Automatic installation mode - choosing upgrade"
            UPGRADE="1"
        fi
    else
        good "Performing new install"
        UPGRADE="0"
    fi

    if [ "${UPGRADE}" == "0" ]; then
        echo ""
        if [ "${OPT_AUTO}" != "1" ]; then
            getparam "Installation prefix" "$SETUP_INSTALL_DIR"
            if [ "x${PARAM}" != "x" ]; then
                SETUP_INSTALL_DIR="$PARAM"
            fi
        else
            good "Automatic installation mode - using ${SETUP_INSTALL_DIR} as installation directory"
        fi

        if [ "${OPT_AUTO}" != "1" ]; then
            getparam "Run services as user" "$SETUP_INSTALL_USER"
            if [ "x$PARAM" != "x" ]; then
                SETUP_INSTALL_USER="$PARAM"
            fi
        else
            good "Automatic installation mode - using ${SETUP_INSTALL_USER} as user";
        fi

        if [ -d "${SETUP_INSTALL_DIR}" ]; then
            echo ""
            if [ "${OPT_AUTO}" != "1" ]; then
                warn "Directory ${SETUP_INSTALL_DIR} already exists
                     Please select full installation or upgrade.
                     Directory ${SETUP_INSTALL_DIR} will be DELETED in full installation!"
                echo ""
                ask_with_confirmation "Upgrade or Install?" "U" "i"
                if [ $? -eq 1 ]; then
                    UPGRADE="1"
                else
                    UPGRADE="0"
                fi
            else
                bad "Automatic installation mode - directory already exists, but previous installation information was not found."
                exit 2
            fi
        fi
    fi

    # check if installation file exists but it is not directory
    if [ "$UPGRADE" == "0" -a -f "$SETUP_INSTALL_DIR" ]; then
        bad "File ${SETUP_INSTALL_DIR} exists but it is not directory."
        exit 1
    fi

    # set server configuration file
    SETUP_SERVER_CONF="/etc/icewarp/icewarp.conf"
}

# Function checks if there is not expired license for upgrade
# Parameters:
#  none
# Returns:
#  none
check_upgrade_license()
{
    # Dear script editors - be warned that server will not work properly without valid license even if you comment this check out ;-)
    if [ "${UPGRADE}" == "1" ]; then
        LICENSE_EXPIRED=$(get_liccheck_variable "system" "C_License_Expired_For_Upgrade")
        if [ "${LICENSE_EXPIRED}" == "1" ]; then
            bad "Cannot upgrade IceWarp Server because of expired license." 
            exit 3
        fi
    fi
}

# Function checks for entered install options. Failed check causes script exit.
# Parameters:
#  none
# Returns:
#  none
check_install_options()
{
    # test if user exists
    id "$SETUP_INSTALL_USER" &> /dev/null
    if [ $? -ne 0 ]; then
        bad "User ${SETUP_INSTALL_USER} doesn't exist."
        exit 1
    fi

    # test if user is in group
    id -g "$SETUP_INSTALL_USER" &> /dev/null
    if [ $? -ne 0 ]; then
        bad "User ${SETUP_INSTALL_USER} is not in group."
        exit 1
    fi
}

# Function asks user to confirm entered installation options
# Parameters:
#  none
# Returns:
#  none
confirm_install_options()
{
    SETUP_INSTALL_GROUP=$(id -gn "$SETUP_INSTALL_USER")

    good ""
    good "Please check entered informations before continuing:"
    good ""
    if [ "$UPGRADE" == "1" ]; then
        good "Installation prefix:\t\t${SETUP_INSTALL_DIR} (upgrading)"
    else
        good "Installation prefix:\t\t${SETUP_INSTALL_DIR} (directory will be created)"
    fi

    good "IceWarp Server will run as user:\t${SETUP_INSTALL_USER}"
    good "IceWarp Server will run as group:\t${SETUP_INSTALL_GROUP}"

    good ""
    good "Press ENTER to continue, CTRL+C to quit"
    if [ "${OPT_AUTO}" != "1" ]; then
        read -s
        echo ""
    else
        good "Automatic installation mode - starting installation."
    fi
    echo ""
}

# Functions check for services and 3rd party processes executed by IceWarp server
# When detected, user has a choice to kill them or exit
check_server_is_running()
{
    # This procedure is performed only when upgrading
    if [ "$UPGRADE" == "0" ]; then
        return
    fi

    SERVICES=( "${SETUP_INSTALL_DIR}/icewarpd" "${SETUP_INSTALL_DIR}/control" "${SETUP_INSTALL_DIR}/cal" "${SETUP_INSTALL_DIR}/im" "${SETUP_INSTALL_DIR}/pop3" "${SETUP_INSTALL_DIR}/smtp" "${SETUP_INSTALL_DIR}/purple/purpleserv" "ctasd.bin" "${SETUP_INSTALL_DIR}/ldap/libexec/slapd" "${SETUP_INSTALL_DIR}/kasperskyupdater" "${SETUP_INSTALL_DIR}/kaspersky/kavehost" "kavscanner" "${SETUP_INSTALL_DIR}/voip/echo-voicemail-service.jar" )

    # At first check, if any services are running
    SERVER_RUNS=1
    for SERVICE in "${SERVICES[@]}"; do
        ps ax | grep "${SERVICE}" | grep -v "grep">/dev/null
        if [ $? -eq 0 ]; then
            SERVER_RUNS=0
        fi
    done

    if [ $SERVER_RUNS -eq 0 ]; then
        warn "Running IceWarp services detected!
        Are you sure you stopped IceWarp server before upgrading?
            
        Press ENTER to kill detected services or Ctrl+C to exit setup"
        if [ "${OPT_AUTO}" != "1" ]; then
            read -s
            echo ""
        else
            good "Automatic installation mode - killing services."
        fi
        echo ""
        
        KILL_SERVICES="1"
        for SERVICE in "${SERVICES[@]}"; do
            ps ax | grep "${SERVICE}" | grep -v "grep" | awk '{ print ($1); }' | while read pid; do
                kill -9 $pid
            done
        done
        
        good "Detected IceWarp services have been killed"
        echo ""
    fi
}

# Function checks for running php processes
# If detected, user is ask to kill them or exit
# Parameters:
#  none
# Returns:
#  none
check_running_php()
{
    # This procedure is performed only when upgrading
    if [ "$UPGRADE" == "1" ]; then
        # Detect, if previous PHP runs
        PHP_DETECTED="0"
        if ps ax | grep "${SETUP_INSTALL_DIR}/php/php" | grep -v "grep">/dev/null; then
            PHP_DETECTED="1"
        fi
        if ps ax | grep "${SETUP_INSTALL_DIR}/scripts/phpd.sh" | grep -v "grep">/dev/null; then
            PHP_DETECTED="1"
        fi
        if ps ax | grep "php-fpm" | grep -v "grep">/dev/null; then
            PHP_DETECTED="1"
        fi
        
        # Warn user and let him decide
        if [ "${PHP_DETECTED}" == "1" ]; then
            if [ "${KILL_SERVICES}" == "0" ]; then
                warn "Running PHP processes of previous version detected
        Are you sure you stopped IceWarp server before upgrading?
            
        Press ENTER to kill detected PHP processes or Ctrl+C to exit setup"
                if [ "${OPT_AUTO}" != "1" ]; then
                    read -s
                    echo ""
                else
                    good "Automatic installation mode - killing PHPs."
                fi
                echo ""
            fi
            
            # Kill detected phps
            ps ax | grep "${SETUP_INSTALL_DIR}/php/php" | grep -v "grep" | awk '{ print($1); }' | while read pid; do
                kill -9 $pid
            done
            
            # Kill phpd.sh script
            ps ax | grep "${SETUP_INSTALL_DIR}/scripts/phpd.sh" | grep -v "grep" | awk '{ print($1); }' | while read pid; do
                kill -9 $pid
            done

            # Kill php-fpm
            ps ax | grep "php-fpm" | grep -v "grep" | awk '{ print($1); }' | while read pid; do
                kill -9 $pid
            done
            
            if [ "${KILL_SERVICES}" == "0" ]; then
                good "Detected PHP processes have been killed"
                echo ""
            fi
        fi
    fi
}

# Checks, if uname -n is resolvable
# This is needed for ctasd to work
check_resolvable_hostname()
{
    HOSTNAME=$(uname -n)
    if ! ping -c 1 -W 5 "${HOSTNAME}" &>/dev/null; then
        warn "Your system hostname \"${HOSTNAME}\" is not resolvable
        This will cause, that Anti-Spam Live will not work

        Press ENTER to continue or Ctrl+C to exit setup"
        if [ "${OPT_AUTO}" != "1" ]; then
            read -s
            echo ""
        else
            bad "Automatic installation mode - wrong hostname configuration."
            exit 2
        fi
        echo ""
    fi
}

# Function loads some paths from path.dat, if the file exists
# The paths are needed for customization extraction in case of build_profile etc.
load_special_paths()
{
    if [ "${UPGRADE}" != "0" ] && [ -f "${SETUP_INSTALL_DIR}/path.dat" ]; then
        SETUP_CONFIG_DIR=$(sed '1p;d' "${SETUP_INSTALL_DIR}/path.dat" | tr -d '\r')
        SETUP_SPAM_DIR=$(sed '6p;d' "${SETUP_INSTALL_DIR}/path.dat" | tr -d '\r')
        SETUP_CALENDAR_DIR=$(sed '7p;d' "${SETUP_INSTALL_DIR}/path.dat" | tr -d '\r')
    fi

    # set to default if not defined in path.dat
    if [ "x${SETUP_CONFIG_DIR}" == "x" ]; then
        SETUP_CONFIG_DIR="${SETUP_INSTALL_DIR}/${SETUP_CONFIG_DIR_DEFAULT}"
    fi
    if [ "x${SETUP_SPAM_DIR}" == "x" ]; then
        SETUP_SPAM_DIR="${SETUP_INSTALL_DIR}/${SETUP_SPAM_DIR_DEFAULT}"
    fi
    if [ "x${SETUP_CALENDAR_DIR}" == "x" ]; then
        SETUP_CALENDAR_DIR="${SETUP_INSTALL_DIR}/${SETUP_CALENDAR_DIR_DEFAULT}"
    fi

    # remove possible trailing slashes
    SETUP_CONFIG_DIR=$(sed 's;/*$;;' <<< "${SETUP_CONFIG_DIR}")
    SETUP_CALENDAR_DIR=$(sed 's;/*$;;' <<< "${SETUP_CALENDAR_DIR}")
    SETUP_SPAM_DIR=$(sed 's;/*$;;' <<< "${SETUP_SPAM_DIR}")

    # if not full path, prepend installation directory
    SETUP_CONFIG_DIR=$(sed "s;^\([^/]\);${SETUP_INSTALL_DIR}\1;" <<< "${SETUP_CONFIG_DIR}")
    SETUP_CALENDAR_DIR=$(sed "s;^\([^/]\);${SETUP_INSTALL_DIR}\1;" <<< "${SETUP_CALENDAR_DIR}")
    SETUP_SPAM_DIR=$(sed "s;^\([^/]\);${SETUP_INSTALL_DIR}\1;" <<< "${SETUP_SPAM_DIR}")
}

# Function checks/creates installation directory
check_install_directory()
{
    if [ "$UPGRADE" == "0" ]; then
        # Install

        good "Creating ${SETUP_INSTALL_DIR} directory ..."

        if [ "x${SETUP_INSTALL_DIR}" == "x/" ]; then
            bad "Rejecting directory removal: ${SETUP_INSTALL_DIR}"
            exit 1
        fi
        rm -rf "$SETUP_INSTALL_DIR"
        mkdir -p "$SETUP_INSTALL_DIR"
        if [ $? -ne 0 ]; then
            bad "Failed! Check permissions."
            exit 1
        fi
    else
        # Upgrade

        # create directory for sure, user can delete installation directory
        # and left configuration file /etc/icewarp.conf on disk
        mkdir -p "$SETUP_INSTALL_DIR"
        if [ $? -ne 0 ]; then
            bad "Cannot create directory '$SETUP_INSTALL_DIR'. Check permissions."
            exit 1
        fi

        # backup commtouch config file
        mv "${SETUP_INSTALL_DIR}/spam/commtouch/ctasd.conf" "${SETUP_INSTALL_DIR}/spam/commtouch/ctasd.conf.bak"

        # remove files which are not in use anymore
        # but not changed by extracting from tar
        if ! [ -d "${SETUP_INSTALL_DIR}/html/admin/old" ]; then
            TMPDIR=$(mktemp -d)
            cp -a "${SETUP_INSTALL_DIR}/html/admin/"* "${TMPDIR}/"
            rm -rf "${SETUP_INSTALL_DIR}/html/admin/"*
            mkdir -p "${SETUP_INSTALL_DIR}/html/admin/old"
            cp -a "${TMPDIR}/"* "${SETUP_INSTALL_DIR}/html/admin/old/"
            rm -rf "${TMPDIR}"
        fi

        # files are removed in final_cleanup()
        true
    fi
}

# Delete old things before extracting package
delete_before_install()
{
    if [ "${UPGRADE}" == "1" ]; then
        rm -rf "${SETUP_INSTALL_DIR}/html/admin/client/languages"
  	    rm -rf "${SETUP_INSTALL_DIR}/lib/ssl"
	      rm -rf "${SETUP_INSTALL_DIR}/lib64/ssl"
    fi
}

# Function extract setupfirst* archives
extract_first_customizations()
{
    if ! ls "${WORKDIR}"/setupfirst*.dat &> /dev/null; then
        return
    fi

    good "Extracting pre-installation customization data ..."
    if [ -f "${WORKDIR}/setupfirst.dat" ]; then
        unzip -n -qq -^ -d "${SETUP_INSTALL_DIR}" "${WORKDIR}/setupfirst.dat"
    fi
    if [ -f "${WORKDIR}/setupfirstconfig.dat" ]; then
        unzip -n -qq -^ -d "${SETUP_CONFIG_DIR}" "${WORKDIR}/setupfirstconfig.dat"
    fi
    if [ -f "${WORKDIR}/setupfirstcalendar.dat" ]; then
        unzip -n -qq -^ -d "${SETUP_CALENDAR_DIR}" "${WORKDIR}/setupfirstcalendar.dat"
    fi
    if [ -f "${WORKDIR}/setupfirstspam.dat" ]; then
        unzip -n -qq -^ -d "${SETUP_SPAM_DIR}" "${WORKDIR}/setupfirstspam.dat"
    fi
}

# Function creates destination directory, extracts tar image
# and in case of installing, it copies default configuration
# files, so all not-generated files are on the place
# Parameters:
#   None
# Returns:
#   None
extract_package()
{
    good "Extracting data ..."
    if [ "$UPGRADE" == "1" ]; then
        # AS live doesn't like old files of itself
        rm -rf "${SETUP_INSTALL_DIR}/spam/commtouch"
    fi

    tar -xf "${WORKDIR}/${IMAGENAME}" -C "$SETUP_INSTALL_DIR"
    if [ $? -ne 0 ]; then
        bad "Failed, check user permissions and available disk space. 512 MB disk space is needed."
        exit 1
    fi

    # In case of installing, copy default configuration files
    if [ "$UPGRADE" == "0" ]; then
        # copy all configuration files

        # calendar
        [ -f "${SETUP_INSTALL_DIR}/calendar/groupware.db" ] || cp -f "${SETUP_INSTALL_DIR}/calendar/default/db/groupware.db" "${SETUP_INSTALL_DIR}/calendar/groupware.db"

        # config
        [ -f "${SETUP_INSTALL_DIR}/config/content.xml" ] || cp -f "${SETUP_INSTALL_DIR}/config/default/content.xml" "${SETUP_INSTALL_DIR}/config/content.xml"
        [ -f "${SETUP_INSTALL_DIR}/config/imservices.dat" ] || cp -f "${SETUP_INSTALL_DIR}/config/default/imservices.dat" "${SETUP_INSTALL_DIR}/config/imservices.dat"
        [ -f "${SETUP_INSTALL_DIR}/config/servicebind.dat" ] || cp -f "${SETUP_INSTALL_DIR}/config/default/servicebind.dat" "${SETUP_INSTALL_DIR}/config/servicebind.dat"
        [ -f "${SETUP_INSTALL_DIR}/config/webserver.dat" ] || cp -f "${SETUP_INSTALL_DIR}/config/default/webserver.dat" "${SETUP_INSTALL_DIR}/config/webserver.dat"
        [ -f "${SETUP_INSTALL_DIR}/config/voicemail.xml" ] || cp -f "${SETUP_INSTALL_DIR}/config/default/voicemail.xml" "${SETUP_INSTALL_DIR}/config/voicemail.xml"
        [ -f "${SETUP_INSTALL_DIR}/config/siprules.dat" ] || cp -f "${SETUP_INSTALL_DIR}/config/default/siprules.dat" "${SETUP_INSTALL_DIR}/config/siprules.dat"

        # antispam
        [ -f "${SETUP_INSTALL_DIR}/spam/antispam.db" ] || cp -f "${SETUP_INSTALL_DIR}/spam/default/db/antispam.db" "${SETUP_INSTALL_DIR}/spam/antispam.db"
        # local.cf needn't be present
        if [ -f "${SETUP_INSTALL_DIR}/spam/default/rules/local.cf" ] && [ ! -f "${SETUP_INSTALL_DIR}/spam/rules/local.cf" ]; then
            cp -f "${SETUP_INSTALL_DIR}/spam/default/rules/local.cf" "${SETUP_INSTALL_DIR}/spam/rules/local.cf"
        fi
        
        # ldap
        [ -f "${SETUP_INSTALL_DIR}/ldap/etc/ldap.conf" ] || cp -f "${SETUP_INSTALL_DIR}/ldap/etc/ldap.conf.default" "${SETUP_INSTALL_DIR}/ldap/etc/ldap.conf"
        [ -f "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf" ] || cp -f "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.default" "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf"
    fi

    # In case of upgrading, check for missing configuration files
    # this is done in function check_settings_files()
}

get_system_timezone()
{
    if [ -f /etc/timezone ]; then
        TZ=`cat /etc/timezone`
    elif [ -h /etc/localtime ]; then
        TZ=`readlink /etc/localtime | sed "s/.*\/usr\/share\/zoneinfo\///"`
    else
        checksum=`md5sum /etc/localtime | cut -d' ' -f1`
        TZ=`find /usr/share/zoneinfo/ -type f -exec md5sum {} \; | grep "^$checksum" | sed "s/.*\/usr\/share\/zoneinfo\///" | grep -v ^posix | head -n 1`
    fi
    
    echo $TZ
}

configure_installation()
{
    DATE=`date`

    # print IceWarp Server configuration file
    DIR_CONFIG=`dirname ${SETUP_SERVER_CONF}`
    mkdir -p "${DIR_CONFIG}"
    if [ $? -ne 0 ]; then
        bad "Can not create directory: ${DIR_CONFIG}"
        exit 1
    fi

    touch "$SETUP_SERVER_CONF"
    if [ $? -ne 0 ]; then
        bad "Can not create file: ${SETUP_SERVER_CONF}"
        exit 1
    fi

    echo "# IceWarp Server configuration file
# this file was generated by IceWarp installer on ${DATE}

# Server installation directory
# IWS_INSTALL_DIR=/path/to/server
IWS_INSTALL_DIR=\"${SETUP_INSTALL_DIR}\"

# Directory with native libraries for server
IWS_LIB_DIR=\"${SETUP_SERVER_LIBDIR}\"

# Platform this server is built for
IWS_PLATFORM=\"${SETUP_SERVER_PLATFORM}\"

# User to run server as
# IWS_PROCESS_USER=username
IWS_PROCESS_USER=\"${SETUP_INSTALL_USER}\"

# IceWarp Server version, used for upgrade process
# IWS_VERSION=number
IWS_VERSION=\"${SETUP_NEWVERSION}\"

# Previous version number, for information
IWS_OLDVERSION=\"${SETUP_OLDVERSION}\"

" > "$SETUP_SERVER_CONF"

    # print settings to php.ini
    echo "
zend_extension = \"${SETUP_INSTALL_DIR}/php/ext/ioncube_loader_lin_5.4.so\"
extension = \"${SETUP_INSTALL_DIR}/php/ext/xcache.so\"
" >> "${SETUP_INSTALL_DIR}/php/php.ini"

    echo "[IceWarp]
icewarp_sharedlib_path = \"${SETUP_INSTALL_DIR}/html/_shared/\"
extension_dir = \"${SETUP_INSTALL_DIR}/php/ext/\"
error_log = \"${SETUP_INSTALL_DIR}/logs/phperror.log\"
open_basedir_ignore = \"${SETUP_INSTALL_DIR}/\"
session.save_path = \"${SETUP_INSTALL_DIR}/php/tmp/\"
sendmail_path = \"${SETUP_INSTALL_DIR}/sendmail -i -t\"
upload_tmp_dir = \"${SETUP_INSTALL_DIR}/php/tmp/\"

; Set timezone to required value
date.timezone = \"$(get_system_timezone)\"
" >> "${SETUP_INSTALL_DIR}/php/php.ini"

    # write timeout settings if they are not in php.user.ini
    if ! [ -f "${SETUP_INSTALL_DIR}/php/php.user.ini" ] \
    || ! grep "icewarpphp.calendarfunctioncall_timeout" "${SETUP_INSTALL_DIR}/php/php.user.ini">/dev/null
    then
        echo "; Timeout of function calendarfunctioncall in milliseconds
icewarpphp.calendarfunctioncall_timeout = 0
" >> "${SETUP_INSTALL_DIR}/php/php.ini"
    fi

    if ! [ -f "${SETUP_INSTALL_DIR}/php/php.user.ini" ] \
    || ! grep "icewarpphp.challengeresponsefunctioncall_timeout" "${SETUP_INSTALL_DIR}/php/php.user.ini">/dev/null
    then
        echo "; Timeout of function challengeresponsefunctioncall in milliseconds
icewarpphp.challengeresponsefunctioncall_timeout = 0
" >> "${SETUP_INSTALL_DIR}/php/php.ini"
    fi

    if ! [ -f "${SETUP_INSTALL_DIR}/php/php.user.ini" ] \
    || ! grep "icewarpphp.apiobjectcall_persistent_timeout" "${SETUP_INSTALL_DIR}/php/php.user.ini">/dev/null
    then
        echo "; Timeout of function apiobjectcall_persistent in milliseconds
icewarpphp.apiobjectcall_persistent_timeout = 0
" >> "${SETUP_INSTALL_DIR}/php/php.ini"
    fi

    # append php.user.ini
    if [ -f "${SETUP_INSTALL_DIR}/php/php.user.ini" ]; then
        echo -e "; Content of php.user.ini" >> "${SETUP_INSTALL_DIR}/php/php.ini"
        cat "${SETUP_INSTALL_DIR}/php/php.user.ini" >> "${SETUP_INSTALL_DIR}/php/php.ini"
        echo "" >> "${SETUP_INSTALL_DIR}/php/php.ini"
    fi

    # Generate empty settings file if not exists - this is a mark, that default should be created
    if ! [ -f "${SETUP_INSTALL_DIR}/config/settings.cfg" ]; then
        touch "${SETUP_INSTALL_DIR}/config/settings.cfg"
    fi
}

# Helper function for check_settings_files()
# Parameters:
#  $1 - source file name, copy from
#  $2 - destination file name to check and copy to
# Returns:
#  None
check_settings_file()
{
    FILE_NAME_SRC=$1
    FILE_NAME_DST=$2
    if [ ! -f "$FILE_NAME_DST" ]; then
        good "Configuration file ${FILE_NAME_DST} does not exist, copying from default."
        cp -f "$FILE_NAME_SRC" "$FILE_NAME_DST"
        if [ $? -ne 0 ]; then
            bad "Can not copy ${FILE_NAME_SRC} to ${FILE_NAME_DST}"
            exit 1
        fi
    fi
}

# Function upgrades settings files from older versions to newest one
# load_special_paths() must be called before this function
# Paramters:
#  none
# Returns:
#  none
check_settings_files()
{
    # this function is needed only for upgrading
    if [ "$UPGRADE" == "0" ]; then
        return 0
    fi

    # extract calendar, config and spam directories into temporary folder
    DIR_TEMP=$(mktemp -d)

    tar -xf "${WORKDIR}/${IMAGENAME}" -C "$DIR_TEMP" calendar
    if [ $? -ne 0 ]; then
        bad "Can not extract calendar files from image"
        exit 1
    fi
    tar -xf "${WORKDIR}/${IMAGENAME}" -C "$DIR_TEMP" config
    if [ $? -ne 0 ]; then
        bad "Can not extract config files from image"
        exit 1
    fi
    tar -xf "${WORKDIR}/${IMAGENAME}" -C "$DIR_TEMP" spam
    if [ $? -ne 0 ]; then
        warn "Can not extract spam files from image"
        SPAM_EXCLUDED=true
    else
        SPAM_EXCLUDED=false
    fi

    # copy files from temp to destination
    cp -fr "${DIR_TEMP}/calendar/"* "$SETUP_CALENDAR_DIR"
    if [ $? -ne 0 ]; then
        bad "Can not copy calendar files"
        exit 1
    fi
    cp -fr "${DIR_TEMP}/config/"* "$SETUP_CONFIG_DIR"
    if [ $? -ne 0 ]; then
        bad "Can not copy config files"
        exit 1
    fi
    if ! $SPAM_EXCLUDED; then
        cp -fr "${DIR_TEMP}/spam/"* "$SETUP_SPAM_DIR"
        if [ $? -ne 0 ]; then
            bad "Can not copy spam files"
            exit 1
        fi
    fi

    # remove temporary directory
    rm -rf "$DIR_TEMP"

    # test if settings files exists, copy one from default

    # Files in calendar directory

    # calendar/groupware.db
    FNAME_SRC="${SETUP_CALENDAR_DIR}/default/db/groupware.db"
    FNAME_DST="${SETUP_CALENDAR_DIR}/groupware.db"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"

    # Files in config directory

    # config/cert.pem
    FNAME_SRC="${SETUP_CONFIG_DIR}/default/cert.pem"
    FNAME_DST="${SETUP_CONFIG_DIR}/cert.pem"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"
    # config/content.xml
    FNAME_SRC="${SETUP_CONFIG_DIR}/default/content.xml"
    FNAME_DST="${SETUP_CONFIG_DIR}/content.xml"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"
    # config/imservices.dat
    FNAME_SRC="${SETUP_CONFIG_DIR}/default/imservices.dat"
    FNAME_DST="${SETUP_CONFIG_DIR}/imservices.dat"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"
    # config/servicebind.dat
    FNAME_SRC="${SETUP_CONFIG_DIR}/default/servicebind.dat"
    FNAME_DST="${SETUP_CONFIG_DIR}/servicebind.dat"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"
    # config/webserver.dat
    FNAME_SRC="${SETUP_CONFIG_DIR}/default/webserver.dat"
    FNAME_DST="${SETUP_CONFIG_DIR}/webserver.dat"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"
    # config/voicemail.xml
    FNAME_SRC="${SETUP_CONFIG_DIR}/default/voicemail.xml"
    FNAME_DST="${SETUP_CONFIG_DIR}/voicemail.xml"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"
    # config/siprules.dat
    FNAME_SRC="${SETUP_CONFIG_DIR}/default/siprules.dat"
    FNAME_DST="${SETUP_CONFIG_DIR}/siprules.dat"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"

    if ! $SPAM_EXCLUDED; then
        # Files in spam directory

        # spam/antispam.db
        FNAME_SRC="${SETUP_SPAM_DIR}/default/db/antispam.db"
        FNAME_DST="${SETUP_SPAM_DIR}/antispam.db"
        check_settings_file "$FNAME_SRC" "$FNAME_DST"
        # spam/rules/local.cf
        FNAME_SRC="${SETUP_SPAM_DIR}/default/rules/local.cf"
        FNAME_DST="${SETUP_SPAM_DIR}/rules/local.cf"
        check_settings_file "$FNAME_SRC" "$FNAME_DST"
    fi

    # Files in ldap directory
    
    # ldap/etc/ldap.conf
    FNAME_SRC="${SETUP_INSTALL_DIR}/ldap/etc/ldap.conf.default"
    FNAME_DST="${SETUP_INSTALL_DIR}/ldap/etc/ldap.conf"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"
    # ldap/etc/slapd.conf
    FNAME_SRC="${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.default"
    FNAME_DST="${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf"
    check_settings_file "$FNAME_SRC" "$FNAME_DST"

    return 0
}

# Function extracts setupcustom* archives
extract_custom_customizations()
{
    if [ -f "${WORKDIR}/setupscript.dat" ]; then
        unzip -o -qq -^ -d "${SETUP_INSTALL_DIR}/scripts" "${WORKDIR}/setupscript.dat"
    fi

    if ! ls "${WORKDIR}"/setupcustom*.dat &> /dev/null; then
        return
    fi

    good "Extracting post-installation customization data ..."
    if [ -f "${WORKDIR}/setupcustom.dat" ]; then
        unzip -o -qq -^ -d "${SETUP_INSTALL_DIR}" "${WORKDIR}/setupcustom.dat"
    fi
    if [ -f "${WORKDIR}/setupcustomconfig.dat" ]; then
        unzip -o -qq -^ -d "${SETUP_CONFIG_DIR}" "${WORKDIR}/setupcustomconfig.dat"
    fi
    if [ -f "${WORKDIR}/setupcustomcalendar.dat" ]; then
        unzip -o -qq -^ -d "${SETUP_CALENDAR_DIR}" "${WORKDIR}/setupcustomcalendar.dat"
    fi
    if [ -f "${WORKDIR}/setupcustomspam.dat" ]; then
        unzip -o -qq -^ -d "${SETUP_SPAM_DIR}" "${WORKDIR}/setupcustomspam.dat"
    fi
}

# Function deals with kaspersky_dist directory - either replaces current sdk or removes it
update_kaspersky()
{
    if [ "$UPGRADE" == "0" ]; then
        # Fresh install, place it there
        rm -rf "${SETUP_INSTALL_DIR}/kaspersky"     # Just to be sure
        mv "${SETUP_INSTALL_DIR}/kaspersky_dist" "${SETUP_INSTALL_DIR}/kaspersky"
    else
        # Upgrade, compare sdk version
        PREVIOUS_KAVSDK_VERSION=$(<"${SETUP_INSTALL_DIR}/kaspersky/sdkversion.txt") 2>/dev/null
        CURRENT_KAVSDK_VERSION=$(<"${SETUP_INSTALL_DIR}/kaspersky_dist/sdkversion.txt")

        if [ "${PREVIOUS_KAVSDK_VERSION}" == "${CURRENT_KAVSDK_VERSION}" ]; then
            # always update libkavi.so
            cp -f "${SETUP_INSTALL_DIR}/kaspersky_dist/${SETUP_SERVER_LIBDIR}/libkavi.so" "${SETUP_INSTALL_DIR}/kaspersky/${SETUP_SERVER_LIBDIR}"/
            # don't update the sdk itself
            rm -rf "${SETUP_INSTALL_DIR}/kaspersky_dist"
        else
            # update whole sdk directory
            rm -rf "${SETUP_INSTALL_DIR}/kaspersky"
            mv "${SETUP_INSTALL_DIR}/kaspersky_dist" "${SETUP_INSTALL_DIR}/kaspersky"
        fi
    fi
}

# Function replaces some setup variables and does edits in config files
# Paramters:
#  none
# Returns:
#  none
patch_settings_files()
{
    SED_SETUP_INSTALL_DIR=$(echo ${SETUP_INSTALL_DIR} | sed -e 's/\(\/\|\\\|&\)/\\&/g')

    # place installation path to kavehost.xml (by replacing env vars)
    rm -f "${SETUP_INSTALL_DIR}/kaspersky/kavehost.xml.new"
    sed "s/\${SETUP_INSTALL_DIR}/${SED_SETUP_INSTALL_DIR}/g" < "${SETUP_INSTALL_DIR}/kaspersky/kavehost.xml" > "${SETUP_INSTALL_DIR}/kaspersky/kavehost.xml.new"
    mv "${SETUP_INSTALL_DIR}/kaspersky/kavehost.xml.new" "${SETUP_INSTALL_DIR}/kaspersky/kavehost.xml"

    # place installation path to ldap configuration files
    rm -f "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.new"
    sed "s/\${SETUP_INSTALL_DIR}/${SED_SETUP_INSTALL_DIR}/g" < "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf" > "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.new"
    mv "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.new" "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf"

    rm -f "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.default.new"
    sed "s/\${SETUP_INSTALL_DIR}/${SED_SETUP_INSTALL_DIR}/g" < "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.default" > "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.default.new"
    mv "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.default.new" "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf.default"

    # place absolute expected lame path in case it is set to default in voicemail.xml
    rm -f "${SETUP_INSTALL_DIR}/config/voicemail.xml.new"
    LAME_DST="${SETUP_INSTALL_DIR}/voip/lame"
    if ! [ -f "${LAME_DST}" ]; then
        LAME_DST="/usr/bin/lame"
    fi
    sed "s:<lamedestination>\.\./lame</lamedestination>:<lamedestination>${LAME_DST}</lamedestination>:" < "${SETUP_INSTALL_DIR}/config/voicemail.xml" > "${SETUP_INSTALL_DIR}/config/voicemail.xml.new"
    mv "${SETUP_INSTALL_DIR}/config/voicemail.xml.new" "${SETUP_INSTALL_DIR}/config/voicemail.xml"
    sed "s:<lamedestination>/usr/bin/lame</lamedestination>:<lamedestination>${LAME_DST}</lamedestination>:" < "${SETUP_INSTALL_DIR}/config/voicemail.xml" > "${SETUP_INSTALL_DIR}/config/voicemail.xml.new"
    mv "${SETUP_INSTALL_DIR}/config/voicemail.xml.new" "${SETUP_INSTALL_DIR}/config/voicemail.xml"

    # place icewarp process user to ctasd.conf
    rm -f "${SETUP_INSTALL_DIR}/spam/commtouch/ctasd.conf.new"
    sed "s/\${SETUP_INSTALL_USER}/${SETUP_INSTALL_USER}/g" < "${SETUP_INSTALL_DIR}/spam/commtouch/ctasd.conf" > "${SETUP_INSTALL_DIR}/spam/commtouch/ctasd.conf.new"
    mv "${SETUP_INSTALL_DIR}/spam/commtouch/ctasd.conf.new" "${SETUP_INSTALL_DIR}/spam/commtouch/ctasd.conf"
}

# Function creates ldap root node
# It is performed regardless if root node exists or not
# Parameters:
#  none
# Returns:
#  none
create_slapd_root()
{
    TMP_LDIF=$(mktemp)

    echo "dn: dc=root
objectClass: dcObject
objectClass: organization
dc: root
description: root
o: Organization
" > "${TMP_LDIF}"

    LD_LIBRARY_PATH="${SETUP_INSTALL_DIR}/ldap/lib" "${SETUP_INSTALL_DIR}/ldap/sbin/slapadd" -f "${SETUP_INSTALL_DIR}/ldap/etc/slapd.conf" -l "${TMP_LDIF}" -b ""
    rm -f "${TMP_LDIF}"
}

# Function checks if custom openssl is used
is_openssl_installed()
{
    ls "${SETUP_INSTALL_DIR}/${SETUP_SERVER_LIBDIR}/libcrypto."* &>/dev/null
    if [ $? -eq 0 ]; then
        return 0
    fi


    ls "${SETUP_INSTALL_DIR}/${SETUP_SERVER_LIBDIR}/libssl."* &>/dev/null
    if [ $? -eq 0 ]; then
        return 0
    fi

    return 1
}

# Function upgrades bundled ssl if it was used in previous version
upgrade_openssl()
{
    if [ "${UPGRADE}" == "1" ] && is_openssl_installed; then
        cp -fd "${SETUP_INSTALL_DIR}/${SETUP_SERVER_LIBDIR}/ssl/"* "${SETUP_INSTALL_DIR}/${SETUP_SERVER_LIBDIR}/"
    fi
}

# Function installs service to system
# Parameters:
#  none
# Returns:
#  none
install_service()
{
    # add/remove merakd as system service
    SERVICE_INSTALLED="0"
    SERVICE_STARTED="0"

    # check if merak service is installed
    service merak status &> /dev/null
    if [ $? -eq 0 ]; then
        good "Service 'merak' was found installed in system"
        good "which is now obsolete and renamed to 'icewarp' service."
        if [ "${OPT_AUTO}" != "1" ]; then
            ask_with_confirmation "Delete service 'merak'?" "Y" "n"
            ANSWER=$?
        else
            good "Automatic installation mode - deleting service merak."
            ANSWER=1
        fi
        if [ ${ANSWER} -eq 1 ]; then
            good "Removing 'merak' system service ..."
            platform_remove_service merak
            rm -f "/etc/init.d/merak"
        fi
    fi

    # check if system service is installed
    good "Checking if IceWarp Server is added as system service ..."
    good "Note: System service can be reinstalled"
    good "      by removing already installed service."
    good ""
    service "$SETUP_INSTALL_SERVICE_NAME" status > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        SERVICE_INSTALLED="1"
        good "IceWarp Server is already added as system service."
        if [ "${OPT_AUTO}" != "1" ]; then
            ask_with_confirmation "Delete service?" "Y" "n"
            ANSWER=$?
        else
            good "Automatic installation mode - deleting icewarp system service."
            ANSWER=1
        fi
        if [ ${ANSWER} -eq 1 ]; then
            good "Removing IceWarp Server system service ..."
            platform_remove_service "$SETUP_INSTALL_SERVICE_NAME"
            rm -f "/etc/init.d/${SETUP_INSTALL_SERVICE_NAME}"
            SERVICE_INSTALLED="0"
        fi
    fi

    # ask and add icewarpd as service
    if [ "$SERVICE_INSTALLED" == "0" ]; then
        if [ "${OPT_AUTO}" != "1" ]; then
            ask_with_confirmation "Do you want to add IceWarp Server as a system service?" "Y" "n"
            ANSWER=$?
        else
            good "Automatic installation mode - adding icewarp system service."
            ANSWER=1
        fi
        if [ ${ANSWER} -eq 1 ]; then
            good "Adding IceWarp Server as system service"
            SERVICE_FILE="/etc/init.d/${SETUP_INSTALL_SERVICE_NAME}"
            # create new service script
            sed "s|%%IWS_INSTALL_DIR_VALUE%%|${SETUP_INSTALL_DIR}|" "${SETUP_INSTALL_DIR}/scripts/setup/${OS_DIST}-${SETUP_INSTALL_SERVICE_NAME}.init" > "$SERVICE_FILE"
            if [ $? -ne 0 ]; then
                bad "Can not create service file."
                return 1
            fi
            chmod 755 "$SERVICE_FILE" > /dev/null
            if [ $? -ne 0 ]; then
                bad "Cannot change permissions on file: ${SERVICE_FILE}"
                return 1
            fi
            SERVICE_INSTALLED="1"
        else
            good "IceWarp Server will not be added as system service."
        fi
    fi

    # ask to add or remove service from runlevel
    if [ "$SERVICE_INSTALLED" == "1" ]; then
        platform_remove_service "$SETUP_INSTALL_SERVICE_NAME"
        if [ "${OPT_AUTO}" != "1" ]; then
            ask_with_confirmation "Do you want to start IceWarp Server on system startup?" "Y" "n"
            ANSWER=$?
        else
            good "Automatic installation mode - making IceWarp Server to start on system startup."
            ANSWER=1
        fi
        if [ ${ANSWER} -eq 1 ]; then
            good "Setting service to start on system startup..."
            platform_add_service "$SETUP_INSTALL_SERVICE_NAME"
            if [ $? -ne 0 ]; then
                bad "Error setting runlevel."
                return 1
            fi
        else
            good "IceWarp Server will not start automatically on system startup."
        fi
    fi

    return 0
}

# Function upgrades server data and tables from previous version to latest
# Parameters:
#  None
# Returns:
#  None
upgrade_server_data()
{
    if [ "$UPGRADE" != "1" ] && ! [ -f "${SETUP_INSTALL_DIR}/scripts/script.php" ]; then
        schedule_antivirus_update
        return 0
    fi
    
    # run upgrade tool if upgrading
    if [ "$UPGRADE" == "1" ]; then
        good ""
        good "It is possible now to upgrade data to the current version."
        good "This process includes possible customization script execution"
        good "To do this, IceWarp Server must be started."
        good "Note: You can run upgrade process later by command"
        good "      in ${SETUP_INSTALL_DIR}: ./upgrade.sh _old_version_"
        good ""
    else
        good ""
        good "It is needed to execute installation customization script."
        good "To do this, IceWarp Server must be started."
        good "Note: You can execute the script manually later by command"
        good "      in ${SETUP_INSTALL_DIR}: ./upgrade.sh"
        good ""
    fi
    
    if [ "${OPT_AUTO}" != "1" ]; then
        ask_with_confirmation "Start services and perform the operation now?" "Y" "n"
        ANSWER=$?
    else
        good "Automatic installation mode - performing upgrade."
        ANSWER=1
    fi
    if [ ${ANSWER} -eq 1 ]; then
        good "Starting IceWarp Server ..."
        "${SETUP_INSTALL_DIR}/icewarpd.sh" --start > /dev/null
        if [ $? -ne 0 ]; then
            bad "Cannot start IceWarp Server"
            exit 1
        fi
        good "Performing upgrade and customization tasks ..."
        sleep 10
        
        if [ "$UPGRADE" == "1" ]; then
            "${SETUP_INSTALL_DIR}/upgrade.sh" "$SETUP_OLDVERSION" > /dev/null
        else
            "${SETUP_INSTALL_DIR}/upgrade.sh" > /dev/null
        fi
        
        if [ $? -eq 0 ]; then
            sleep 10
            good "Data upgrade and customization script completed successfully"
        else
            bad "Data upgrade or customization script problem!"
        fi

        good "Restarting IceWarp Server ..."
        "${SETUP_INSTALL_DIR}/icewarpd.sh" --stop > /dev/null
        if [ $? -ne 0 ]; then
            bad "Cannot restart IceWarp Server, please do the restart manually"
        fi

        schedule_antivirus_update
        
        "${SETUP_INSTALL_DIR}/icewarpd.sh" --start > /dev/null
        if [ $? -ne 0 ]; then
            bad "Cannot restart IceWarp Server, please do the restart manually"
        fi
    else
        schedule_antivirus_update
    fi
}

# Disable document preview components, if crucial tools are missing
configure_docpreview()
{
    if [ "${CONVERSION_DOC_PDF}" == "0" ]; then
        "${SETUP_INSTALL_DIR}/tool.sh" set system C_GW_DocumentPDFConversion 0 >/dev/null
    fi

    if [ "${CONVERSION_PDF_IMAGE}" == "0" ]; then
        "${SETUP_INSTALL_DIR}/tool.sh" set system C_GW_PDFImageConversion 0 >/dev/null
    fi
}

# Schedule antivirus update
schedule_antivirus_update()
{
    touch "${SETUP_INSTALL_DIR}/var/updateav"
    chown -h "${SETUP_INSTALL_USER}:${SETUP_INSTALL_GROUP}" "${SETUP_INSTALL_DIR}/var/updateav"
}

change_user_owner()
{
    # All files are installed OK, change permissions
    good "Changing permissions ..."
    if [ "${UPGRADE}" == "1" ]; then
        MAIL_PATH=$("${SETUP_INSTALL_DIR}/tool.sh" "get" "system" "C_System_Storage_Dir_MailPath" | sed 's/^.* //' | sed 's/\/$//')
        ARCHIVE_PATH=$("${SETUP_INSTALL_DIR}/tool.sh" "get" "system" "C_System_Tools_AutoArchive_Path" | sed 's/^.* //' | sed 's/\/$//')
        if [ "${ARCHIVE_PATH:0:1}" != "/" ]; then
            ARCHIVE_PATH="${SETUP_INSTALL_DIR}/${ARCHIVE_PATH}"
        fi
        find "${SETUP_INSTALL_DIR}" -path "${MAIL_PATH}" -prune -o -path "${ARCHIVE_PATH}" -prune -o -print0 | xargs -0 chown -h "${SETUP_INSTALL_USER}:${SETUP_INSTALL_GROUP}"
    else
        # Fresh installation
        chown -h -R "${SETUP_INSTALL_USER}:${SETUP_INSTALL_GROUP}" "${SETUP_INSTALL_DIR}"
        if [ $? -ne 0 ]; then
            bad "Failed! Check user permissions on ${SETUP_INSTALL_DIR}"
            "Setup continues ..."
        fi
    fi
}

final_cleanup()
{
    # binaries
    rm -f "${SETUP_INSTALL_DIR}/merakd"
    rm -f "${SETUP_INSTALL_DIR}/startd"
    rm -f "${SETUP_INSTALL_DIR}/stopd"
    rm -f "${SETUP_INSTALL_DIR}/restartd"
    # scripts
    rm -f "${SETUP_INSTALL_DIR}/merakd.sh"
    # sockets
    rm -f "${SETUP_INSTALL_DIR}/var/icewarpd.sock"
    rm -f "${SETUP_INSTALL_DIR}/var/phpsocket"
    # previous configuration
    rm -f "${SETUP_INSTALL_DIR}/config/icewarp.conf"
    rm -f "${SETUP_INSTALL_DIR}/config/merak.conf"
    # libraries needed for 32bit server on 64bit platform
    if  [ "${OS_PLATFORM}" != "x86_64" ] && [ -f "${SETUP_INSTALL_DIR}/lib/liblist_x86.txt" ]; then
      while read line; do
          rm -f "${SETUP_INSTALL_DIR}/lib/${line}"
      done < "${SETUP_INSTALL_DIR}/lib/liblist_x86.txt"
    fi
    rm -f "${SETUP_INSTALL_DIR}/lib/liblist_x86.txt"
}

start_server_wait_groupware()
{
	if [ "${UPGRADE}" != "0" ]; then
		return
	fi
	
	good "Starting IceWarp Server ..."
	"${SETUP_INSTALL_DIR}/icewarpd.sh" --start > /dev/null
	if [ $? -ne 0 ]; then
		warn "Cannot start IceWarp Server"
	else
		good "IceWarp Server started"
		echo ""
	fi
	
	good "Waiting for groupware being available ..."
	GW_READY=false
	MAX_WAIT=60
	while [ $MAX_WAIT -gt 0 ]; do
		GW_AVAIL=$(get_api_variable "system" "C_GW_IsAvailable")
		if [ "${GW_AVAIL}" == "1" ]; then
			GW_READY=true
			break
		fi
		sleep 1
		MAX_WAIT=$(($MAX_WAIT - 1))
	done
	
	if $GW_READY; then
		good "Groupware is ready"
	else
		warn "Waiting for groupware timed out. Please check IceWarp server state."
		echo "                 It is possible the initial setup won't fully succeed."
		echo "                 Press ENTER to continue"
		read -s
	fi
	echo ""
}

create_initial_data()
{
    if [ "$UPGRADE" != "0" ]; then
        return
    fi

    INIT_DOMAIN="icewarpdemo.com"
    INIT_USER="admin@icewarpdemo.com"
    INIT_PASSWORD="admin"

    good "Initial domain and user with administrator privileges can be created now."
    ask_with_confirmation "Create initial domain and user?" "Y" "n"
    if [ $? -ne 1 ]; then
        return
    fi

    "${SETUP_INSTALL_DIR}/tool.sh" "create" "domain" "$INIT_DOMAIN" "d_description" "Initial domain" "d_adminemail" "$INIT_USER" &> /dev/null
    if [ $? -ne 0 ]; then
        bad "Error creating domain $INIT_DOMAIN"
    else
        "${SETUP_INSTALL_DIR}/tool.sh" "set" "system" "c_accounts_policies_pass_enable" "0" &> /dev/null
        "${SETUP_INSTALL_DIR}/tool.sh" "create" "account" "$INIT_USER" "u_name" "System and domain administrator" "u_password" "$INIT_PASSWORD" "u_admin" "1" &> /dev/null
        if [ $? -ne 0 ]; then
            bad "Error creating user $INIT_USER"
        else
            good "Initial domain and user was created:"
            good "Domain: $INIT_DOMAIN"
            good "User: $INIT_USER"
            good "Password: $INIT_PASSWORD"
        fi
        "${SETUP_INSTALL_DIR}/tool.sh" "set" "system" "c_accounts_policies_pass_enable" "1" &> /dev/null
    fi
}

# Function sets all smartdiscover items to use given hostname
# Parameters: $1 - hostname
set_hostname_to_smartdiscover()
{
    if [ "x$1" == "x" ]; then return; fi

    "${SETUP_INSTALL_DIR}/tool.sh" set system c_activesync_url "http://$1/Microsoft-Server-ActiveSync" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_syncml_url "http://$1/syncml/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_webdav_url "http://$1/webdav/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_gw_webdavurl "http://$1/webdav/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_webmail_url "http://$1/webmail/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_webadmin_url "http://$1/admin/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_freebusy_url "http://$1/freebusy/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_gw_freebusyurl "http://$1/freebusy/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_internetcalendar_url "http://$1/calendar/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_smsservice_url "http://$1/sms/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_as_spamchallengeurl "http://$1/reports/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_install_url "http://$1/install/" &>/dev/null
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_teamchat_api_url "https://$1/teamchatapi/" &>/dev/null
}

new_installation_wizard()
{
    if [ "$UPGRADE" != "0" ]; then
        return
    fi
 
    HOSTNAME_OK=false
    DOMAIN_OK=false
    ADMIN_OK=false
    
    while ! $DOMAIN_OK || ! $HOSTNAME_OK || ! $ADMIN_OK; do
        if ! $HOSTNAME_OK; then
            INIT_HOSTNAME=$(uname -n)
            echo ""
            good "Enter the name of your server. This is the hostname you will use to access your server"
            good "from the Internet. You should setup the DNS as explained in the documentation."
            getparam "Hostname" "$INIT_HOSTNAME"
            if [ "x$PARAM" != "x" ]; then
                if [ "${PARAM}" != "${INIT_HOSTNAME}" ]; then
                    echo ""
                    warn "You have entered another hostname, than is set in the system.
        Please note, that system hostname has to be configured properly
        and has to be resolvable by DNS, or some components won't work."
                fi
                INIT_HOSTNAME="$PARAM"
            fi
        fi

        if ! $DOMAIN_OK; then
            INIT_DOMAIN="icewarpdemo.com"
            echo ""
            getparam "Enter the name of primary domain" "$INIT_DOMAIN"
            if [ "x$PARAM" != "x" ]; then
                INIT_DOMAIN="$PARAM"
            fi
        fi
        
        if ! $ADMIN_OK; then
            INIT_USERNAME="admin"
            INIT_PASSWORD=""
            CONFIRM_PASSWORD=""

            echo ""
            good "Enter the username and password for the administrator account."
            good "Choose a strong password to avoid account hijacking."
            getparam "Username" "$INIT_USERNAME"
            if [ "x$PARAM" != "x" ]; then
                INIT_USERNAME="$PARAM"
            fi
            getpassword "Password"
            if [ "x$PARAM" != "x" ]; then
                INIT_PASSWORD="$PARAM"
            fi
            getpassword "Confirm password"
            if [ "x$PARAM" != "x" ]; then
                CONFIRM_PASSWORD="$PARAM"
            fi            
        fi

        ADMIN_EMAIL="${INIT_USERNAME}@${INIT_DOMAIN}"
        
        # Create domain
        if ! $DOMAIN_OK; then
            "${SETUP_INSTALL_DIR}/tool.sh" create domain "${INIT_DOMAIN}" D_AdminEmail "${ADMIN_EMAIL}" D_Postmaster "${POSTMASTER_ALIASES}" D_SharedRoster >"${HELPER_WIZARD_FILE}" 2>&1
            if [ $? -ne 0 ]; then
                echo ""
                bad "Error creating domain ${INIT_DOMAIN}"
                bad "$(<"${HELPER_WIZARD_FILE}")"
            else
                DOMAIN_OK=true
            fi
        fi

        # Set hostname
        if ! $HOSTNAME_OK; then
            "${SETUP_INSTALL_DIR}/tool.sh" set system C_Mail_SMTP_General_HostName "${INIT_HOSTNAME}" >"${HELPER_WIZARD_FILE}" 2>&1
            if [ $? -ne 0 ]; then
                echo ""
                bad "Error setting hostname ${INIT_HOSTNAME}"
                bad "$(<"${HELPER_WIZARD_FILE}")"
            else
                HOSTNAME_OK=true
            fi

            # Set IM services names
            sed "s/icewarpdemo.com/${INIT_HOSTNAME}/" < "${SETUP_INSTALL_DIR}/config/imservices.dat" > "${SETUP_INSTALL_DIR}/config/imservices.dat.new"
            mv "${SETUP_INSTALL_DIR}/config/imservices.dat.new" "${SETUP_INSTALL_DIR}/config/imservices.dat"
            chown -h "${SETUP_INSTALL_USER}:${SETUP_INSTALL_GROUP}" "${SETUP_INSTALL_DIR}/config/imservices.dat"

            # Set smartdiscover
            set_hostname_to_smartdiscover "${INIT_HOSTNAME}"
        fi

        # Create admin account
        if ! $ADMIN_OK; then
            if [ "${INIT_PASSWORD}" != "${CONFIRM_PASSWORD}" ]; then
                bad "Entered passwords don't match"
            else
                "${SETUP_INSTALL_DIR}/tool.sh" create account "${ADMIN_EMAIL}" U_Alias "${INIT_USERNAME}" U_Mailbox "${INIT_USERNAME}" U_Password "${INIT_PASSWORD}" U_Name "${INIT_USERNAME}" U_Admin 1 >"${HELPER_WIZARD_FILE}" 2>&1
                ADMIN_CREATE_RESULT=$?
                if [ $ADMIN_CREATE_RESULT -ne 0 ]; then
                    echo ""
                    bad "Creating administrator account failed"
                    case $ADMIN_CREATE_RESULT in
                        4)  bad "Account already exists!"
                            ;;
                        5)  bad "Password violates password policy!"
                    echo "        Password cannot contain username or alias, must be at least 6 characters long"
                    echo "        and must contain at least 1 numeric and 1 alpha character."
                            ;;
                        *)  bad "Account save problem!"
                            bad "$(<"${HELPER_WIZARD_FILE}")"
                            ;;
                    esac
                else
                    ADMIN_OK=true
                fi
            fi
        fi
        
        rm -f "${HELPER_WIZARD_FILE}"

        if ! $DOMAIN_OK || ! $HOSTNAME_OK || ! $ADMIN_OK; then
            echo ""
            ask_with_confirmation "Retry?" "Y" "n"
            if [ $? -ne 1 ]; then
                echo ""
                warn "Please use a wizard or other tool to configure the server"
                return
            fi
        fi
    done
    
    # Make default self signed domain cert and Lets Encrypt
    good "Generating default certificates ..."
    "${SETUP_INSTALL_DIR}/tool.sh" set system c_CreateDefaultCertificates "${INIT_DOMAIN}" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        good "Certificates successfully added."
    else
        bad "Certificates couldn't be created."
    fi
}

rejoice()
{
    good ""
    if [ "$UPGRADE" == "0" ]; then
        good "IceWarp Server was successfully installed."
    else
        good "IceWarp Server was successfully upgraded."
    fi
    good ""
}

license_questions()
{
    if [ "${UPGRADE}" == "0" ]; then
        if [ "x${OPT_LICENSE}" != "x" ]; then
            good "Activating license..."
            "${SETUP_INSTALL_DIR}/tool.sh" set system c_onlinelicense "${OPT_LICENSE}"
            if [ $? -eq 0 ]; then
                good "License activation successful."
            else
                bad "License activation error."
                exit 1
            fi
        elif [ "${OPT_AUTO}" != "1" ]; then
            good "IceWarp Server is fully functional only with registered license."
            good "If you already have a license (trial or purchased) you can activate it now."
            good "If you don't have it yet, you can register a trial for 30 days."
            echo ""
            ask_with_confirmation "Do you want to run wizard and obtain trial license now?" "Y" "n"
            if [ $? -eq 1 ]; then
                "${SETUP_INSTALL_DIR}/scripts/wizard.sh" "action" "license_obtain_trial"
            else
                ask_with_confirmation "Do you want to run wizard and activate license you already have?" "Y" "n"
                if [ $? -eq 1 ]; then
                    "${SETUP_INSTALL_DIR}/scripts/wizard.sh" "action" "license_online"
                else
                    echo ""
                    good "Please use wizard.sh or other tool to activate your license."
                    good "Your 30 day evaluation has started now."
                    echo ""
                    warn "IceWarp Server is not fully functional in evaluation mode without a license!"
                fi
            fi
        fi
    fi
    good ""
}

copyright()
{
    good ""
    good "IceWarp Server installer"
    good "(c) 1999-2015 IceWarp Ltd. "
    good ""
}

getscriptparams()
{
    case $1 in
    "-h"|"--help")
        copyright
        good ""
        good "Usage: $0 [-f|--fast] [--allow-missing-architecture] [-a|--auto] [--install-dir=<installation directory>] [--user=<user>] [--license=<order id>]"
        good ""
        good "Options:"
        good "    -f or --fast"
        good "         Skip new installation wizard, create default admin."
        good "    --allow-missing-architecture"
        good "         Allow installation on multiarch distros even if i386 architecture is not present."
        good "    -a or --auto"
        good "         Skip all interactive questions, use default values"
        good "    --install-dir"
        good "         Specify installation directory. This is /opt/icewarp by default in auto mode."
        good "    --user"
        good "         Specify an user under which the IceWarp Server will run. Default user in auto mode is root."
        good "    --license"
        good "         Specify an order ID of your license. If license is not specified in auto mode, IceWarp server is installed without any license."
        good ""   
        good "This script provides functionality for installing or upgrading IceWarp Server."
        good "Default action is to install but if the following conditions are met,"
        good "only upgrade will be performed:"
        good "  1. entered destination directory exists"
        good "  2. file INSTALL_DESTINATION_DIRECTORY/config/merak.conf or"
        good "     file INSTALL_DESTINATION_DIRECTORY/config/icewarp.conf exists"
        good ""
        good "Install mode extracts all files and creates configuration files"
        good "from default configuration file directories."
        good ""
        good "Upgrade mode:"
        good "  1. replaces all files which are not configuration files"
        good "     (i.e. files not modified by running server)"
        good "  2. recreates default configuration files that do not exists:"
        good "       ./calendar/groupware.db"
        good "       ./config/cert.pem"
        good "       ./config/webserver.dat"
        good "       ./spam/antispam.dat"
        good "       ./spam/rules/local.cf"
        good ""
        good "[END]"
    ;;
    *)
        parse_cmdline $*
        accept_license
        display_log_info
        #
        # part 1.
        #
        # detect needed programs and dependencies
        # allow to install them, if they are missing
        test_correct_osdist
        test_correct_platform
        test_selinux
        detect_install_options
        test_unwanted_downgrade
        test_platform_specifics
        test_dependencies
        test_programs
        #
        # part 2.
        #
        # extract server files, and create server configuration file
        # so server can be started. Some settings files can be incorrect
        # which will be fixed in Part 2. 
        #
        ask_questions
        check_upgrade_license
        check_install_options
        confirm_install_options
        check_server_is_running
        check_running_php
        check_resolvable_hostname
        load_special_paths
        check_install_directory
        delete_before_install
        extract_first_customizations
        extract_package
        configure_installation          # generate configuration files
        #
        # part 3.
        #
        # all files required for server starting are now in place:
        # image is extracted, server configuration file is generated
        #
        check_settings_files            # checks if setting file is missing, if yes replace with default one
        extract_custom_customizations
        update_kaspersky
        patch_settings_files            # replace variables with install path etc.
        create_slapd_root               # this is always done, regardless if root already exists
        upgrade_openssl
        install_service
        change_user_owner
        upgrade_server_data
        configure_docpreview
        #
        # Part 4.
        #
        # server is fully installed and configured, delete not needed things
        final_cleanup
        start_server_wait_groupware
        #
        # Part 5.
        #
        # create initial domain and user
        if [ "${OPT_AUTO}" != "1" ]; then
            if [ "$OPT_FAST_INSTALL_MODE" -eq "0" ]; then
                new_installation_wizard
            else
                create_initial_data
            fi
        fi
        rejoice
        license_questions
    ;;
    esac
}

copy_log_files_to_instdir()
{
    if [ -f "/etc/icewarp/icewarp.conf" ]; then
        source "/etc/icewarp/icewarp.conf"

        # Copy logs to icewarp directory for future reference
        mkdir -p "${IWS_INSTALL_DIR}/logs/setup"
        cp -f "${INSTALL_LOG}" "${IWS_INSTALL_DIR}/logs/setup"
        cp -f "${INSTALL_ERROR_LOG}" "${IWS_INSTALL_DIR}/logs/setup"
    fi
}

# this install script can be executed only by user with root privileges
if [ "x${RUNNING_UID}" != "x0" ]; then
    bad "This install script can be executed by root user only."
    exit 1
fi

DATE=$(date)

touch "$INSTALL_LOG"
touch "$INSTALL_ERROR_LOG"

echo "INSTALLATION STARTED ON ${DATE}" > "$INSTALL_LOG"
echo "INSTALLATION STARTED ON ${DATE}" > "$INSTALL_ERROR_LOG"
detect_os_distribution
getscriptparams $* 2>> "$INSTALL_ERROR_LOG" | tee -a "$INSTALL_LOG"
echo "INSTALLATION FINISHED ON ${DATE}" >> "$INSTALL_LOG"
echo "INSTALLATION FINISHED ON ${DATE}" >> "$INSTALL_ERROR_LOG"

copy_log_files_to_instdir


exit 0

