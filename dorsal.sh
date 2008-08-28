#!/usr/bin/env bash

### Define helper functions ###

quit_if_fail() {
    # Exit with some useful information if something goes wrong
    status=$?
    if [ $status -ne 0 ]
	then
	echo 'Failure with exit status:' $status
	echo 'Exit message:' $1
	exit $status
    fi
}

package_fetch (){
    # First make sure we're in the right directory before downloading
    cd ${DOWNLOAD_PATH}

    echo "Fetching ${NAME}"

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
	echo "Unpacking ${NAME}"
	# Make sure the tarball was downloaded
	if [ ! -e ${NAME}${PACKING} ]
	then
	    echo "${NAME}${PACKING} does not exist. Please download first."
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

package_specific_build() {
    # We are already in the appropriate build folder
    if [ ${BUILDCHAIN} = "autotools" ]
    then
	./configure --prefix=${INSTALL_PATH}
	make
	make install
    elif [ ${BUILDCHAIN} = "python" ]
    then
	python setup.py install --prefix=${INSTALL_PATH}
    elif [ ${BUILDCHAIN} = "custom" ]
    then
	echo "You have forgotten to overload the custom build function package_specific_build()."
    fi
} 

package_build() {
    # Get things ready for the compilation process 
    echo "Building ${NAME}"
    if [ ! -d "${NAME}" ]
    then
        echo "${NAME} does not exist -- please unpack first."
        exit 1
    fi

    # Move to the appropriate folder before compilation
    cd ${NAME}
    package_specific_build

    # Quit with a useful message if someting goes wrong
    quit_if_fail "There was a problem building ${NAME}."
}

#### Start the build process ###

export ORIGDIR=`pwd`

# Read configuration variables from dorsal.cfg
source dorsal.cfg

# If any important variables are missing, revert them to defaults
if [ -z "$DOWNLOAD_PATH" ]
then
    DOWNLOAD_PATH=$HOME/downloads/src
fi

if [-x "$INSTALL_PATH" ]
then
    INSTALL_PATH=$HOME/builds
fi

# Check if dorsal.sh was invoked coerrectly
if [ $# -ne 1 ]
then
    echo "Error: Platform to build for not specified."
    echo "Correct usage: ./dorsal.sh platforms/foo.platform"
    exit 1
fi

# Make sure the requested platform exists
if [ -e "$1" ]
then
    source $1
else
    echo "Platform set '`basename -s .platform $1`' not found. Refer README to check if your platform is supported."
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
        echo "packages/${PACKAGE}.package does not exist yet. Please create it."
        exit 1
    fi

    unset NAME
    unset SOURCE
    unset PACKING
    unset BUILDCHAIN
    
    source packages/${PACKAGE}.package

    if [ ! ${NAME} ] || [ ! ${SOURCE} ] || [ ! ${PACKING} ] || [ ! ${BUILDCHAIN} ]
    then
	echo "${PACKAGE}.package is not properly formed. Please check that all necessary variables are defined."
	exit 1
    fi

    package_fetch
    package_unpack
    package_build
done