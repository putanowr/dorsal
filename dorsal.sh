#!/usr/bin/env bash

# Plan
# 1. Needs a master loop to read platform sets
# 2. Need to implement other worker functions
# 3. Think about adding package-specific variables to their individual
#    package files


if [ $# -ne 1 ]
then
    echo "Error: Platform to build for not specified."
    echo "Correct usage: ./dorsal.sh platforms/foo.platform"
    exit 1
fi

source dorsal.cfg

if [ -z "$DISTDIR" ]
then
        # set DISTDIR to /usr/src/distfiles if not already set
        DISTDIR=/usr/src/distfiles
fi
export DISTDIR

quit_if_fail() {
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
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ]
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
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ]
    then
	echo "Unpacking ${NAME}"
	# Make sure the tarball was downloaded
	if [ ! -e ${NAME}${PACKING} ]
	then
	    echo "${NAME}${PACKING} does not exist. Please download first."
	    exit 1
	fi
	# Set appropriate untar flag
	if [ ${PACKING} = ".tar.bz2" ]
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
	echo "./configure --prefix=${INSTALL_PATH}"
	echo "make"
	echo "make install"
    elif [ ${BUILDCHAIN} = "python" ]
    then
	echo "python setup.py install"
    elif [ ${BUILDCHAIN} = "custom" ]
    then
	echo "You have forgotten to overload the custom build function package_specific_build()."
    fi

    # Quit with a useful message if someting goes wrong
    quit_if_fail "There was a problem building ${NAME}."
    
#         if [ -e configure ]
#         then
#                 #run configure script if it exists
#                 ./configure --prefix=/usr
#         fi
#         #run make
#         make $MAKEOPTS MAKE="make $MAKEOPTS"  
} 

package_build() {

    echo "Building ${NAME}"
    if [ ! -d "${NAME}" ]
    then
        echo "${NAME} does not exist -- please unpack first."
        exit 1
    fi
    # Move to the appropriate folder before compilation
    cd ${NAME}
    package_specific_build
}

export ORIGDIR=`pwd`

if [ -e "$1" ]
then
    source $1
else
    echo "Platform set '`basename -s .platform $1`' not found. Refer README to check if your platform is supported."
    exit 1
fi

mkdir -p ${DOWNLOAD_PATH}

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

# case "${2}" in
#         fetch)
# 	        package_fetch
# 		;;
#         unpack)
#                 package_unpack
#                 ;;
#         build)
#                 package_build
#                 ;;
#         all)
# 	        package_fetch
#                 package_unpack
# 		package_build
#                 ;;
#         *)
#                 echo "Please specify fetch, unpack, build or all as the second arg"
#                 exit 1
#                 ;;
# esac