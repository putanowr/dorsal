#!/usr/bin/env bash

# TODO
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

package_unpack() {
        #make sure we're in the right directory 
        cd ${ORIGDIR}
        
        if [ -d ${WORKDIR} ]
        then    
                rm -rf ${WORKDIR}
        fi

        mkdir ${WORKDIR}
        cd ${WORKDIR}
        if [ ! -e ${DISTDIR}/${A} ]
        then
                echo "${DISTDIR}/${A} does not exist.  Please download first."
                exit 1
        fi
        tar xzf ${DISTDIR}/${A}
        echo "Unpacked ${DISTDIR}/${A}."
        #source is now correctly unpacked
}

user_build() {
        #we're already in ${SRCDIR}
        if [ -e configure ]
        then
                #run configure script if it exists
                ./configure --prefix=/usr
        fi
        #run make
        make $MAKEOPTS MAKE="make $MAKEOPTS"  
} 

package_build() {
        if [ ! -d "${SRCDIR}" ]
        then
                echo "${SRCDIR} does not exist -- please unpack first."
                exit 1
        fi
        #make sure we're in the right directory  
        cd ${SRCDIR}
        user_build
}

export ORIGDIR=`pwd`
export WORKDIR=${ORIGDIR}/work

if [ -e "$1" ]
then
    source $1
else
    echo "Platform set '`basename -s .platform $1`' not found. Refer README to check if your platform is supported."
    exit 1
fi

export SRCDIR=${WORKDIR}/${P}

case "${2}" in
        fetch)
	        package_fetch
		;;
        unpack)
                package_unpack
                ;;
        build)
                package_build
                ;;
        all)
	        package_fetch
                package_unpack
		package_build
                ;;
        *)
                echo "Please specify fetch, unpack, build or all as the second arg"
                exit 1
                ;;
esac