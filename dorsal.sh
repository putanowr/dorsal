#!/usr/bin/env bash

if [ $# -ne 2 ]
then
        echo "Please specify package file and unpack, compile or all"
        exit 1
fi

source /etc/package.conf

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
        echo "Package file $1 not found."
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