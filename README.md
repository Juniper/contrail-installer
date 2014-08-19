contrail-installer
==================

contrail-installer is a set of scripts and utilities to quickly 
build, install, configure and deploy OpenContrail.

# Versions

The contrail-installer master branch generally points to trunk versions 
of OpenContrail components.  For older, stable versions, use appropriate
release name. For example:

    cd contrail-installer
    git checkout R1.06 (release 1.06)

    or

    cd contrail-installer
    git checkout stable/mainline (stable mainline version)

# OpenContrail localrc

OpenContrail uses ``localrc`` to contain all local configuration and customizations. 
Best to start with a sample localrc.

    cd contrail-installer
    cp samples/localrc-all localrc

CONTRAIL_DEFAULT_INSTALL - Set this to True for installation from OpenContrail PPA. 
When set to False, top of trunk OpenContrail bits will be downloaded and compiled. 
Default is to use OpenContrail packages (released version or snapshots).

PHYSICAL_INTERFACE - This is external interface Vrouter should bind to. It should have
a valid IP address configured.

INSTALL_PORFILE - Set this to ALL to for an all in one node. 

# OpenContrail script

Contrail.sh is the main script that supports following options:

    build     ... to build OpenContrail
    Install   ... to Install OpenContrail
    configure ... to Configure & Provision 
    start     ... to Start OpenContrail Modules
    stop      ... to Stop OpenContrail Modules

# Launcing OpenContrail

Run the following NOT AS ROOT:

    cd contrail-installer
    git checkout R1.06 (if using release 1.06 version)
    cp samples/localrc-all localrc (edit localrc as needed)
    ./contrail.sh build
    ./contrail.sh install
    ./contrail.sh configure
    ./contrail.sh start

# OpenContrail+Devstack

R1.06 and trunk currently work with stable/havana and trunk of devstack.

    git clone git@github.com:openstack-dev/devstack
    
A glue file is needed in the interim till it is upstreamed to devstack

    cp ~/contrail-installer/devstack/lib/neutron_plugin/opencontrail lib/neutron_plugin/

Use a sample localrc:

    cp ~/contrail-installer/devstack/samples/localrc-all localrc

Run stack.sh

    cd devstack
    git checkout stable/havana
    (edit localrc as needed - physical interface, host ip ...)
    ./stack.sh
