contrail-installer
==================

Install scripts for OpenContrail

# Versions

The contrail-installer master branch generally points to trunk versions 
of OpenContrail components.  For older, stable versions, use appropriate
release name in the contrail-installer repo.  For example, to create a
OpenContrail cloud from release 1.06:

    cd contrail-installer
    git checkout R1.06

# OpenContrail localrc

OpenContrail uses ``localrc`` to contain all local configuration and customizations. 
More and more of the configuration variables available are passed-through to the individual 
Module configuration files.  Start with a sample localrc

    cd contrail-installer
    cp samples/localrc-all localrc

CONTRAIL_DEFAULT_INSTALL Set this to True for installation from OpenContrail PPA. When set
to False, installation will work with top of trunk OpenContrail bits. Default is to
use OpenContrail packages (released or snapshots).

PHYSICAL_INTERFACE=eth0 This is external interface Vrouter should bind to. It should have
a valid IP address configured.

INSTALL_PORFILE Set this to ALL to for an all in one node. 

# OpenContrail script

Contrail.sh is the main script that supports following options:
    ./contrail.sh build   ... to build OpenContrail
    ./contrail.sh Install ... to Install OpenContrail
    ./contrail.sh Install ... to Configure & Provision 
    ./contrail.sh start   ... to Start OpenContrail Modules
    ./contrail.sh stop    ... to Stop OpenContrail Modules

# Launcing an OpeContrail Cloud

Run the following NOT AS ROOT:
   cd contrail-installer
   git checkout R1.06 (if using release 1.06 version)
   cp samples/localrc-all localrc (edit localrc as needed)
   ./contrail.sh build
   ./contrail.sh install
   ./contrail.sh configure
   ./contrail.sh start

# OpenContrail+Devstack

R1.06 and trunk work with havana release of openstack.
    git clone git@github.com:openstack-dev/devstack
    git checkout stable/havana
    
A glue file is needed in the interim till it is upstreamed to devstack
    cp ~/contrail-installer/devstack/lib/neutron_plugin/opencontrail lib/neutron_plugin/

Use a sample localrc:
    cp ~/contrail-installer/devstack/samples/localrc-all localrc

Run stack.sh
    cd devstack
    git checkout stable/havana
    ./stack.sh
