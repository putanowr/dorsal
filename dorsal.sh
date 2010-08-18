#!/usr/bin/env bash
set -a

# This is Dorsal. Refer to the files README and COPYING for more
# information about it as well as terms of distribution.

### Define helper functions ###

# Colours for progress and error reporting
BAD="\033[1;31m"
GOOD="\033[1;32m"
BOLD="\033[1m"

prettify_dir() {
   # Make a directory name more readable by replacing homedir with "~"
   echo ${1/#$HOME\//~\/}
}

cecho() {
    # Display messages in a specified colour
    COL=$1; shift
    echo -e "${COL}$@\033[0m"
}

default () {
    # Export a variable, if it is not already set
    VAR="${1%%=*}"
    VALUE="${1#*=}"
    eval "[[ \$$VAR ]] || export $VAR='$VALUE'"
}

quit_if_fail() {
    # Exit with some useful information if something goes wrong
    STATUS=$?
    if [ ${STATUS} -ne 0 ]
    then
	cecho ${BAD} 'Failure with exit status:' ${STATUS}
	cecho ${BAD} 'Exit message:' $1
	exit ${STATUS}
    fi
}

package_fetch () {
    # First, make sure we're in the right directory before downloading
    cd ${DOWNLOAD_PATH}

    cecho ${GOOD} "Fetching ${NAME}"

    # Fetch the package appropriately from its source
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ] || [ ${PACKING} = ".tbz2" ] || [ ${PACKING} = ".tgz" ]
    then
	# Only download tarballs that do not exist
	if [ ! -e ${NAME}${PACKING} ]
	then
	    wget --no-check-certificate -c ${SOURCE}${NAME}${PACKING}
	fi
    elif [ ${PACKING} = "hg" ]
    then
	# Suitably clone or update hg repositories
	if [ ! -d ${NAME} ]
	then
	    hg clone ${SOURCE}${NAME}
	else
	    cd ${NAME}
	    hg pull --update
	    cd ..
	fi
    elif [ ${PACKING} = "svn" ]
    then
	# Suitably check out or update svn repositories
	if [ ! -d ${NAME} ]
	then
	    svn co ${SOURCE} ${NAME}
	else
	    cd ${NAME}
	    svn up
	    cd ..
	fi
    elif [ ${PACKING} = ".git" ]
    then
	# Suitably clone or update git repositories
	if [ ! -d ${NAME} ]
	then
	    git clone ${SOURCE}${NAME}${PACKING}
	else
	    cd ${NAME}
	    git pull
	    cd ..
	fi
    elif [ ${PACKING} = "bzr" ]
    then
	# Suitably branch or update bzr repositories
	if [ ! -d ${NAME} ]
	then
	    bzr branch ${SOURCE}${NAME}
	else
	    cd ${NAME}
	    bzr pull
	    cd ..
	fi
    fi

    # Quit with a useful message if something goes wrong
    quit_if_fail "Error fetching ${NAME}."
}

package_unpack() {
    # First make sure we're in the right directory before unpacking
    cd ${DOWNLOAD_PATH}

    default EXTRACTSTO=${NAME}

    # Only need to unpack tarballs
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ] ||  [ ${PACKING} = ".tbz2" ] || [ ${PACKING} = ".tgz" ]
    then
	cecho ${GOOD} "Unpacking ${NAME}"
	# Make sure the tarball was downloaded
	if [ ! -e ${NAME}${PACKING} ]
	then
	    cecho ${BAD} "${NAME}${PACKING} does not exist. Please download first."
	    exit 1
	fi
	# Set appropriate decompress flag
	if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tbz2" ]
	then
	    C="j"
	else
	    C="z"
	fi

	# Unpack the tarball only if it isn't already
	if [ ! -d "${EXTRACTSTO}" ]
	then
	    tar x${C}f ${NAME}${PACKING}
	fi
    fi

    # Quit with a useful message if something goes wrong
    quit_if_fail "Error unpacking ${NAME}."
}

package_build() {
    # Get things ready for the compilation process
    cecho ${GOOD} "Building ${NAME}"
    if [ ! -d "${EXTRACTSTO}" ]
    then
	cecho ${BAD} "${EXTRACTSTO} does not exist -- please unpack first."
	exit 1
    fi

    if [ x"${CLEANBUILD}" = "xyes" ]
    then
       BUILDDIR=${BUILD_PATH}/${EXTRACTSTO}
       SRCDIR=${DOWNLOAD_PATH}/${EXTRACTSTO}
    else
       BUILDDIR=${EXTRACTSTO}
       SRCDIR=.
    fi

    # Create build directory if it does not exist
    if [ ! -d ${BUILDDIR} ]
    then
      mkdir -p ${BUILDDIR}
    fi

    # Move to the build directory
    cd ${BUILDDIR}

    # Carry out any package-specific setup
    package_specific_setup
    quit_if_fail "There was a problem in build setup for ${NAME}."

    # Use the appropriate build system to compile and install the
    # package

    echo "#!/usr/bin/env bash" >dorsal_build

    # Write variables to file so that it can be run stand-alone
    declare -x >>dorsal_build

    # From this point in dorsal_build, errors are fatal
    echo "set -e" >>dorsal_build

    if [ ${BUILDCHAIN} = "autotools" ]
    then
	if [ ! -e Makefile ] && [ ! -e makefile ] && [ ! -e GNUmakefile ]
	then
	    ${SRCDIR}/configure ${CONFOPTS} --prefix=${INSTALL_PATH}
	    quit_if_fail "There was a problem configuring build for ${NAME}."
	fi
	for target in "${TARGETS[@]}"
	do
	    echo make -j ${PROCS} $target >>dorsal_build
	done
    elif [ ${BUILDCHAIN} = "python" ]
    then
	echo python setup.py install --prefix=${INSTALL_PATH} >>dorsal_build
    elif [ ${BUILDCHAIN} = "scons" ]
    then
	for target in "${TARGETS[@]}"
	do
	    echo python `which scons` -j ${PROCS} ${SCONSOPTS} prefix=${INSTALL_PATH} $target >>dorsal_build
	done
    elif [ ${BUILDCHAIN} = "custom" ]
    then
        # Write the function definition to file
	declare -f package_specific_build >>dorsal_build
	echo package_specific_build >>dorsal_build
    fi

    chmod a+x dorsal_build
    if [ ${BASH_VERSINFO} -ge 3 ]
    then
        # Log the build
	set -o pipefail
	./dorsal_build 2>&1 | tee build_log
    else
	./dorsal_build
    fi
    quit_if_fail "There was a problem building ${NAME}."

    # Carry out any package-specific post-build instructions
    package_specific_install
}

package_register() {
    # Get ready to set environment variables related to the package
    cd ${DOWNLOAD_PATH}
    default EXTRACTSTO=${NAME}
    if [ ! -d "${EXTRACTSTO}" ]
    then
	cecho ${BAD} "${EXTRACTSTO} does not exist -- please install at least once."
	exit 1
    fi

    # Move to the package directory
    cd ${EXTRACTSTO}

    # Set any package-specific environment variables
    package_specific_register
    quit_if_fail "There was a problem setting environment variables for ${NAME}."
}

guess_platform() {
  # Try to guess the name of the platform we're running on
  if [ -f /usr/bin/cygwin1.dll ]
  then
      echo xp
  elif [ -x /usr/bin/sw_vers ]
  then
    local MACOSVER=$(sw_vers -productVersion)
    case ${MACOSVER} in
      10.4*) 	echo tiger;;
      10.5*)	echo leopard;;
      10.6*)	echo snowleopard;;
    esac
  elif [ -x /usr/bin/lsb_release ]; then
    local DISTRO=$(lsb_release -i -s)
    local CODENAME=$(lsb_release -c -s)
    local DESCRIPTION=$(lsb_release -d -s)
    case ${DISTRO}:${CODENAME}:${DESCRIPTION} in
      Ubuntu:*:*)           echo ${CODENAME};;
      Debian:*:*)           echo ${CODENAME};;
      Gentoo:*:*)           echo gentoo;;
      *:Cambridge:*)        echo fedora10;;
      *:Leonidas:*)         echo fedora11;;
      *:Constantine:*)      echo fedora12;;
      *:Goddard:*)          echo fedora13;;
      *:Nahant*:*)          echo rhel4;;
      *:Tikanga*:*)         echo rhel5;;
      *:*:CentOS*\ 4*)      echo rhel4;;
      *:*:CentOS*\ 5*)      echo rhel5;;
      *:*:openSUSE\ 11.1*)  echo opensuse11.1;;
      *:*:openSUSE\ 11.2*)  echo opensuse11.2;;
      *:*:openSUSE\ 11.3*)  echo opensuse11.3;;
    esac
  fi
}

guess_architecture() {
  # Try to guess the architecture of the platform we are running on
  ARCH=unknown
  if [ -x /usr/bin/uname -o -x /bin/uname ]
  then
  	ARCH=`uname -m`
  fi
	case ${ARCH} in
	    *_64) echo "64";;
	    i?86) echo "32";;
	    *)	  echo $ARCH;;
	esac
}

### Start the build process ###

export ORIG_DIR=`pwd`

# Read configuration variables from dorsal.cfg
source dorsal.cfg

# For changes specific to your local setup or for debugging, use local.cfg
if [ -f local.cfg ]
then
    source local.cfg
fi

# If any variables are missing, revert them to defaults
default PROJECT=FEniCS
default DOWNLOAD_PATH=${HOME}/Work/FEniCS/src
default INSTALL_PATH=${HOME}/Work/FEniCS
default BUILD_PATH=${HOME}/Work/FEniCS/build
default PROCS=1
default STABLE_BUILD=true


# Check if project was specified correctly
if [ -d ${PROJECT} ]
then
  if [ -d ${PROJECT}/platforms -a -d ${PROJECT}/packages ]
  then
    cecho ${GOOD} "Found configuration for project ${PROJECT}."
  else
    cecho ${BAD} "No subdirectories 'platforms' and 'packages' in ${PROJECT}."
    echo "Please make sure there exists proper project configuration directory."
    exit 1
  fi
else
  cecho ${BAD} "Error: No project configuration directory found for project ${PROJECT}."
  echo "Please check if you have specified right project name in dorsal.cfg"
  echo "Please check if you have directory called ${PROJECT}"
  echo "with subdirectories ${PROJECT}/platforms and ${PROJECT}/packages"
  exit 1
fi

# Check if dorsal.sh was invoked correctly
if [ $# -eq 0 ]
then
    PLATFORM=${PROJECT}/platforms/`guess_platform`.platform
    if ! [ -e ${PLATFORM} ]
    then
	cecho ${BAD} "Error: Platform to build for not specified (and not automatically recognised)."
	echo "If you know the platform you are interested in (myplatform), please specify it directly, as:"
	echo "./dorsal.sh ${PROJECT}/platforms/myplatform.platform"
	echo "If you'd like to learn more, refer to the file USAGE for detailed usage instructions."
	echo "Fedora/Redhat users may need to run 'yum install redhat-lsb' and then try dorsal.sh again."
	exit 1
    fi
    cecho ${GOOD} "Building ${PROJECT} for with ${PLATFORM}:"
    echo "-------------------------------------------------------------------------------"
    # Show the initial comments in the platform file, as it often
    # contains instructions about packages that should be installed
    # first, etc. Remove first field '#' so that cut-and-paste of
    # e.g. apt-get commands is easy.
    awk '/^##/ {exit} {$1=""; print}' <${PLATFORM}
    echo
    echo "Downloading files to:   $(prettify_dir ${DOWNLOAD_PATH})"
    echo "Installing projects in: $(prettify_dir ${INSTALL_PATH})"
    echo
    if [ ${STABLE_BUILD} = true ]
    then
	echo "Building stable point-releases of ${PROJECT} projects."
    else
	echo "Building development versions of ${PROJECT} projects."
    fi
    echo "-------------------------------------------------------------------------------"
    cecho ${GOOD} "Please make sure you've read the instructions above and your system"
    cecho ${GOOD} "is ready for installing ${PROJECT}. We find it easiest to copy and paste"
    cecho ${GOOD} "these instructions in another terminal window."
    echo ""
    cecho ${GOOD} "Once ready, hit enter to continue!"
    read
elif [ $# -eq 1 ]
then
    PLATFORM=${1}
elif [ $# -eq 2 ]
then
    # Check if the user wants to install a single package
    if [ ${1} == "install-package" ]
    then
	PACKAGE=${2}
        # Check if the package exists
	if [ ! -e ${PROJECT}/packages/${PACKAGE}.package ]
	then
	    cecho ${BAD} "${PROJECT}/packages/${PACKAGE}.package does not exist yet. Please create it."
	    exit 1
	fi
	PACKAGES=(${PACKAGE})
	PLATFORM="${PROJECT}/platforms/.single"
    else
	echo "If you'd like to install a single package, please use the syntax:"
	echo "./dorsal.sh install-package foo"
	exit 1
    fi
fi

# Make sure the requested platform exists
if [ -e "${PLATFORM}" ]
then
    source ${PLATFORM}
else
    cecho ${BAD} "Platform set '${PLATFORM}' not found. Refer to the file README to check if your platform is supported."
    exit 1
fi

# If the platform doesn't override the system python by installing its
# own, figure out the version of of the existing python
default PYTHONVER=`python -c "import sys; print sys.version[:3]"`

# Create necessary directories and set appropriate variables
mkdir -p ${DOWNLOAD_PATH}
mkdir -p ${BUILD_PATH}
mkdir -p ${INSTALL_PATH}/bin
mkdir -p ${INSTALL_PATH}/lib
mkdir -p ${INSTALL_PATH}/include
mkdir -p ${INSTALL_PATH}/lib/python${PYTHONVER}/site-packages
export PATH=${INSTALL_PATH}/bin:${PATH}
export LD_LIBRARY_PATH=${INSTALL_PATH}/lib:${LD_LIBRARY_PATH}
export DYLD_LIBRARY_PATH=${INSTALL_PATH}/lib:${DYLD_LIBRARY_PATH}
export PYTHONPATH=${INSTALL_PATH}/lib/python${PYTHONVER}/site-packages:${PYTHONPATH}
export PKG_CONFIG_PATH=${INSTALL_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH}
ORIG_PROCS=${PROCS}

# Add some extra library paths for 64 bit machines
guess_architecture
if [ "$ARCH" == "x86_64" ]; then
    export LD_LIBRARY_PATH=${INSTALL_PATH}/lib64:${LD_LIBRARY_PATH}
    export DYLD_LIBRARY_PATH=${INSTALL_PATH}/lib64:${DYLD_LIBRARY_PATH}
    export PYTHONPATH=${INSTALL_PATH}/lib64/python${PYTHONVER}/site-packages:${PYTHONPATH}
fi

# Fetch and build individual packages
for PACKAGE in ${PACKAGES[@]}
do
    # Return to the main Dorsal directory
    cd ${ORIG_DIR}

    # Skip building this package if the user requests for it
    SKIP=false
    if [ ${PACKAGE:0:5} = "skip:" ]
    then
	SKIP=true
	PACKAGE=${PACKAGE#skip:}
    fi

    # Check if the package exists
    if [ ! -e ${PROJECT}/packages/${PACKAGE}.package ]
    then
        cecho ${BAD} "${PROJECT}/packages/${PACKAGE}.package does not exist yet. Please create it."
        exit 1
    fi

    # Reset package-specific variables
    unset NAME
    unset SOURCE
    unset PACKING
    unset BUILDCHAIN
    unset CONFOPTS
    unset SCONSOPTS
    unset EXTRACTSTO
    unset CLEANBUILD
    TARGETS=('' install)
    PROCS=${ORIG_PROCS}

    # Reset package-specific functions
    package_specific_setup () { true; }
    package_specific_build () { true; }
    package_specific_install () { true; }
    package_specific_register () { true; }

    # Fetch information pertinent to the package
    source ${PROJECT}/packages/${PACKAGE}.package

    # Turn to a stable version of the package if that's what the user
    # wants and it exists
    if [ ${STABLE_BUILD} = true ] && [ -e ${PROJECT}/packages/${PACKAGE}-stable.package ]
    then
	source ${PROJECT}/packages/${PACKAGE}-stable.package
    fi

    # Ensure that the package file is sanely constructed
    if [ ! ${NAME} ] || [ ! ${SOURCE} ] || [ ! ${PACKING} ] || [ ! ${BUILDCHAIN} ]
    then
        cecho ${BAD} "${PACKAGE}.package is not properly formed. Please check that all necessary variables are defined."
        exit 1
    fi

    if [ ${SKIP} = false ]
    then
        # Fetch, unpack and build the current package
	package_fetch
	package_unpack
	package_build
    else
        # Let the user know we're skipping the current package
	cecho ${GOOD} "Skipping ${NAME}"
    fi
    package_register
done

cecho ${GOOD} "Build finished."
