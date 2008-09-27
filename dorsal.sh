#!/usr/bin/env bash

# This is Dorsal. Refer README and COPYING for more information about
# it as well as terms of distribution.

### Define helper functions ###

# Colours for progress and error reporting
BAD="\033[1;37;41m"
GOOD="\033[1;37;42m"

quit_if_fail() {
    # Exit with some useful information if something goes wrong
    status=$?
    if [ $status -ne 0 ]
	then
	echo -en "${BAD}"
	echo 'Failure with exit status:' $status
	echo 'Exit message:' $1
	echo -en "\033[0m"
	exit $status
    fi
}

package_fetch (){
    # First make sure we're in the right directory before downloading
    cd ${DOWNLOAD_PATH}

    echo -en "${GOOD}"
    echo "Fetching ${NAME}"
    echo -en "\033[0m"

    # Fetch the package appropriately from its source
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ] || [ ${PACKING} = ".tbz2" ] || [ ${PACKING} = ".tgz" ]
    then
	# Only fetch tarballs that do not exist
	if [ ! -e ${NAME}${PACKING} ]
	then
	    wget -c ${SOURCE}${NAME}${PACKING}
	fi
    elif [ ${PACKING} = "hg" ]
    then
	# Suitably clone or update hg packages
	if [ ! -d ${NAME} ]
	then
	    hg clone ${SOURCE}${NAME}
	else
	    cd ${NAME}
	    hg pull --update ${SOURCE}${NAME}
	    cd ..
	fi
    fi
    
    # Quit with a useful message if someting goes wrong
    quit_if_fail "Error fetching ${NAME}."
}

package_unpack() {
    # First make sure we're in the right directory before unpacking
    cd ${DOWNLOAD_PATH}

    # Only need to unpack tarballs
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ] ||  [ ${PACKING} = ".tbz2" ] || [ ${PACKING} = ".tgz" ]
    then
	echo -en "${GOOD}"
	echo "Unpacking ${NAME}"
	echo -en "\033[0m"
	# Make sure the tarball was downloaded
	if [ ! -e ${NAME}${PACKING} ]
	then
	    echo -en "${BAD}"
	    echo "${NAME}${PACKING} does not exist. Please download first."
	    echo -en "\033[0m"
	    exit 1
	fi
	# Set appropriate untar flag
	if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tbz2" ]
	then
	    C="j"
	else
	    C="z"
	fi

	# Unpack the tarball only if it isn't already
	if [ ! -d "${NAME}" ]
	then
	    tar x${C}f ${NAME}${PACKING}
	fi
    fi

    # Quit with a useful message if someting goes wrong
    quit_if_fail "Error unpacking ${NAME}."
}

package_build() {
    # Get things ready for the compilation process
    echo -en "${GOOD}"
    echo "Building ${NAME}"
    echo -en "\033[0m"
    if [ ! -d "${NAME}" ] && [ ! -d "${EXTRACTSTO}" ]
    then
	echo -en "${BAD}"
        echo "${NAME} does not exist -- please unpack first."
	echo -en "\033[0m"
        exit 1
    fi

    # Move to the appropriate folder before compilation
    if [ -z "$EXTRACTSTO" ]
    then
	cd ${NAME}
    else
	cd ${EXTRACTSTO}
    fi

    # Use the appropriate build system to compile and install the
    # package
    if [ ${BUILDCHAIN} = "autotools" ]
    then
	if [ ! -e Makefile ] 
	then
	    ./configure ${CONFOPTS} --prefix=${INSTALL_PATH}
	fi
	make
	make install
    elif [ ${BUILDCHAIN} = "python" ]
    then
	python setup.py install --prefix=${INSTALL_PATH}
    elif [ ${BUILDCHAIN} = "custom" ]
    then
	# Add a check here to make sure it's properly defined
	package_specific_build
    fi

    # Quit with a useful message if someting goes wrong
    quit_if_fail "There was a problem building ${NAME}."
}

### Start the build process ###

export ORIGDIR=`pwd`

# Read configuration variables from dorsal.cfg
source dorsal.cfg

# If any important variables are missing, revert them to defaults
if [ -z "$DOWNLOAD_PATH" ]
then
    DOWNLOAD_PATH=$HOME/downloads/src
fi

if [ -z "$INSTALL_PATH" ]
then
    INSTALL_PATH=$HOME/builds
fi

# Check if dorsal.sh was invoked correctly
if [ $# -ne 1 ]
then
    echo -en "${BAD}"
    echo "Error: Platform to build for not specified."
    echo -en "\033[0m"
    echo "Correct usage: ./dorsal.sh platforms/foo.platform"
    exit 1
fi

# Make sure the requested platform exists
if [ -e "$1" ]
then
    source $1
else
    echo -en "${BAD}"
    echo "Platform set '`basename -s .platform $1`' not found. Refer README to check if your platform is supported."
    echo -en "\033[0m"
    exit 1
fi

# Create necessary directories and export appropriate variables
mkdir -p ${DOWNLOAD_PATH}
mkdir -p ${INSTALL_PATH}
export PATH=$INSTALL_PATH/bin:$PATH
export LD_LIBRARY_PATH=$INSTALL_PATH/lib:$LD_LIBRARY_PATH
export PYTHONPATH=$INSTALL_PATH/lib/python2.5/site-packages:$PYTHONPATH
export PKG_CONFIG_PATH=$INSTALL_PATH/lib/pkgconfig:$PKG_CONFIG_PATH:/usr/lib/pkgconfig

# Fetch and build individual packages
for PACKAGE in ${PACKAGES[@]} 
do
    cd ${ORIGDIR}
    if [ ! -e packages/${PACKAGE}.package ]
    then
	echo -en "${BAD}"
        echo "packages/${PACKAGE}.package does not exist yet. Please create it."
	echo -en "\033[0m"
        exit 1
    fi

    unset NAME
    unset SOURCE
    unset PACKING
    unset BUILDCHAIN
    unset CONFOPTS
    unset EXTRACTSTO
    unset -f package_specific_build
    
    source packages/${PACKAGE}.package

    if [ ! ${NAME} ] || [ ! ${SOURCE} ] || [ ! ${PACKING} ] || [ ! ${BUILDCHAIN} ]
    then
	echo -en "${BAD}"
	echo "${PACKAGE}.package is not properly formed. Please check that all necessary variables are defined."
	echo -en "\033[0m"
	exit 1
    fi

    package_fetch
    package_unpack
    package_build
done