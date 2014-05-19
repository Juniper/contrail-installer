#!/usr/bin/env bash

# **install_pip.sh**

# install_pip.sh [--pip-version <version>] [--use-get-pip] [--force]
#
# Update pip and friends to a known common version

# Assumptions:
# - update pip to $INSTALL_PIP_VERSION

set -o errexit
set -o xtrace

# Keep track of the current directory
TOP_DIR=`pwd`

# Change dir to top of devstack
cd $TOP_DIR

# Import common functions
source $TOP_DIR/functions


# Handle arguments

USE_GET_PIP=${USE_GET_PIP:-0}
INSTALL_PIP_VERSION=${INSTALL_PIP_VERSION:-"1.4.1"}
while [[ -n "$1" ]]; do
    case $1 in
        --force)
            FORCE=1
            ;;
        --pip-version)
            INSTALL_PIP_VERSION="$2"
            shift
            ;;
        --use-get-pip)
            USE_GET_PIP=1;
            ;;
    esac
    shift
done

PIP_GET_PIP_URL=https://raw.github.com/pypa/pip/master/contrib/get-pip.py
PIP_TAR_URL=https://pypi.python.org/packages/source/p/pip/pip-$INSTALL_PIP_VERSION.tar.gz

GetDistro
echo "Distro: $DISTRO"

function get_versions() {
    PIP=$(which pip 2>/dev/null || which pip-python 2>/dev/null || true)
    if [[ -n $PIP ]]; then
        PIP_VERSION=$($PIP --version | awk '{ print $2}')
        echo "pip: $PIP_VERSION"
    else
        echo "pip: Not Installed"
    fi
}


function install_get_pip() {
        (
	   curl -O $PIP_GET_PIP_URL; \
        )
}

function install_pip_tarball() {
    if [[ -f pip-$INSTALL_PIP_VERSION.tar.gz ]]; then
    echo "Skipping downloading of pip-$INSTALL_PIP_VERSION.tar.gz"
    (
        tar xvfz pip-$INSTALL_PIP_VERSION.tar.gz 1>/dev/null; \
        cd pip-$INSTALL_PIP_VERSION; \
        sudo -E python setup.py install 1>/dev/null; \
    )
    else
    (
	curl -O $PIP_TAR_URL; \
        tar xvfz pip-$INSTALL_PIP_VERSION.tar.gz 1>/dev/null; \
        cd pip-$INSTALL_PIP_VERSION; \
        sudo -E python setup.py install 1>/dev/null; \
    )
    fi
}

# Show starting versions
get_versions


# Eradicate any and all system packages
uninstall_package python-pip

if [[ "$USE_GET_PIP" == "1" ]]; then
    install_get_pip
else
    install_pip_tarball
fi

get_versions
