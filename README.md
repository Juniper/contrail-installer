contrail-installer
==================

contrail-installer is a set of scripts and utilities to quickly 
build, install, configure and deploy OpenContrail. It can be used
with pre-build packages (e.g. Launchpad PPA) or from sources. It
is typically used in conjunction with devstack.

# Versions

The contrail-installer master branch generally points to trunk versions 
of OpenContrail components whether sources or snapshots.  For older, 
stable versions, use appropriate release name. 

Currently contrail-installer supports the following:

    contrail-installer: sources master,    devstack: stable/kilo
    contrail-installer: sources R3.0,      devstack: stable/kilo
    contrail-installer: packages R2.20,    devstack: stable/kilo

# OpenContrail localrc

OpenContrail uses ``localrc`` to contain all local configuration and customizations. 
Best to start with a sample localrc.

    cd contrail-installer
    cp samples/localrc-all localrc

CONTRAIL_DEFAULT_INSTALL - Set this to True for installation from OpenContrail binary
packages. When set to False, trunk OpenContrail bits will be downloaded and compiled. 

LAUNCHPAD_BRANCH=PPA - Applicable only when CONTRAIL_DEFAULT_INSTALL is set to True.
It specifies to use released binary packages for installation. Default is to use 
latest snapshots as this knob is commented out by default in sample localrc.

PHYSICAL_INTERFACE - This is external interface Vrouter should bind to. It should have
a valid IP address configured. For example eth0

INSTALL_PROFILE - Set this to ALL to for an all in one node. 

USE_SCREEN - Set this to True to launch contrail modules in a screen session called
"contrail". Connect to screen session for any troubleshooting of contrail modules.

LOGFILE - Specify logfile for contrail.sh runs. By default this is log/contrail.log
in contrail-installer directory

# OpenContrail script

Contrail.sh is the main script that supports following options:

    build     ... to build OpenContrail
    Install   ... to Install OpenContrail
    configure ... to Configure & Provision 
    start     ... to Start OpenContrail Modules
    stop      ... to Stop OpenContrail Modules
    restart   ... to Restart OpenContrail Modules without resetting data

# Launching OpenContrail

Run the following NOT AS ROOT:

    cd contrail-installer
    cp samples/localrc-all localrc (edit localrc as needed)
    ./contrail.sh build
    ./contrail.sh install
    ./contrail.sh configure
    ./contrail.sh start

# OpenContrail+Devstack

Trunk of contrail-installer currently work with stable/juno.


    git clone git@github.com:openstack-dev/devstack
    
A glue file is needed in the interim till it is upstreamed to devstack

    cp ~/contrail-installer/devstack/lib/neutron_plugins/opencontrail lib/neutron_plugins/

Use a sample localrc:

    cp ~/contrail-installer/devstack/samples/localrc-all localrc

Run stack.sh

    cd devstack
    git checkout stable/juno
    (edit localrc as needed - physical interface, host ip ...)
    ./stack.sh

# Restarting OpenContrail+Devstack

If you need to restart OpenContrail or Devstack for some reason, currently they
need to be synchronized. So

    cd ~/devstack
    ./unstack.sh
    cd ~/contrail-installer
    ./contrail.sh stop

    cd ~/contrail-installer
    ./contrail.sh start
    cd ~/devstack
    ./stack.sh

# Verify installation
1) screen -x contrail and run through various tabs to see various contrail modules are running
2) Run utilities/contrail-status to see if all services are running
