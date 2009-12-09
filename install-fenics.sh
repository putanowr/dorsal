#!/usr/bin/env bash

# Set default values of some useful variables
export VERSION="0.5.1"          # Latest released Dorsal version
export PREFIX=${HOME}/local     # Default download/install location
export ORIG_DIR=`pwd`           # Store original directory, so we can
				# return to it when finished

# Colours for progress and error reporting
BAD="\033[1;37;41m"
GOOD="\033[1;37;42m"
BOLD="\033[1m"

### Define helper functions ###

cecho() {
    # Display messages in a specified colour
    COL=$1; shift
    echo -e "${COL}$@\033[0m"
}

# Make a directory name more readable by replacing homedir with ~
prettify_dir() {
   echo ${1/#$HOME\//~\/}
}

# Make a directory name entered with ~ for the homedir more portable
unprettify_dir() {
   echo ${1/#~\//$HOME\/}
}

# Fetch the latest released version of Dorsal
fetch_dorsal() {
    cd ${TMPDIR}
    cecho ${GOOD} "Fetching the FEniCS installer files"
    wget -N http://launchpad.net/dorsal/trunk/${VERSION}/+download/dorsal-${VERSION}.tar.gz
    tar -xzf dorsal-${VERSION}.tar.gz
    cd dorsal-${VERSION}
}

# Set up the build configuration (using some sensible defaults)
cfg_dorsal() {
    export DOWNLOAD_PATH=${PREFIX}/src
    export INSTALL_PATH=${PREFIX}/build
    export PROCS=2
    export STABLE_BUILD=true
    echo "DOWNLOAD_PATH=${DOWNLOAD_PATH}"  > dorsal.cfg
    echo "INSTALL_PATH=${INSTALL_PATH}"   >> dorsal.cfg
    echo "PROCS=${PROCS}"                 >> dorsal.cfg
    echo "STABLE_BUILD=${STABLE_BUILD}"   >> dorsal.cfg
}

# Run the build script
run_dorsal() {
    ./dorsal.sh
    cd ${ORIG_DIR}
}


while :
 do
    clear
    echo "-----------------------------------------------------------"
    echo "             Welcome to the FEniCS installer"
    echo "-----------------------------------------------------------"
    echo ""
    echo "      [1] Change the default install path [$(prettify_dir ${PREFIX})]"
    echo "      [2] Install FEniCS!"
    echo "      [3] Quit the installer"
    echo ""
    echo "Enter the appropriate menu choice"
    echo ""
    echo "-----------------------------------------------------------"
    echo ""
    echo -n "What would you like to do? [1-3]: "
    echo ""
    read OPTION
    case ${OPTION} in
	1)  echo "Please enter your preferred install path: ";
	    read PREFIX
	    PREFIX=$(unprettify_dir ${PREFIX})
	    ;;
	2)  fetch_dorsal
            cfg_dorsal
	    run_dorsal
	    ;;
	3)  cd ${ORIG_DIR}
	    exit 0
	    ;;
	*) ;;
    esac
    echo ""
done