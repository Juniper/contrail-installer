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

Trunk of contrail-installer currently works with stable/kilo


    git clone git@github.com:openstack-dev/devstack
    
A glue file is needed in the interim till it is upstreamed to devstack

    cp ~/contrail-installer/devstack/lib/neutron_plugins/opencontrail lib/neutron_plugins/

Use sample localrc:

    cp ~/contrail-installer/devstack/samples/localrc-all localrc

Run stack.sh

    cd devstack
    git checkout stable/kilo
    (edit localrc as needed - physical interface, host ip ...)
    ./stack.sh

# Restarting OpenContrail+Devstack

If you need to restart OpenContrail or Devstack for some reason, currently they
need to be synchronized. So

    cd ~/devstack
    ./unstack.sh

    cd ~/contrail-installer
    ./contrail.sh restart
    cd ~/devstack
    ./stack.sh

if issues persist, it might be helpful to reboot server or VM and repeat the steps
below

    cd ~/contrail-installer
    ./contrail.sh start
    cd ~/devstack
    ./stack.sh

# Verify installation
    1) screen -x contrail and run through various tabs to see various contrail modules are running
    2) Run utilities/contrail-status to see if all services are running


# Running sanity
Note that default sample localrc enables simple gateway. A script is available that will
create a virtual network, launch two VMs, ping each VM from host and then SSH into it.
Follow the steps below:

    cd ~/contrail-installer/utilities
    export CONTRAIL_DIR=~/contrail-installer
    export DEVSTACK_DIR=~/devstack
    ./contrail-sanity

# Automating contrail.sh and devstack
contrail-installer/utilities/task.sh attempts to automate steps required by sequential runs
of contrail.sh and devstack. It works off a configuration file. Default called auto.conf is
provided. Following example launches task.sh in binary PPA mode while using R2.20 packages.
See auto.conf for more options to launch in source mode or with use of snapshots

    $ cd ~/contrail-installer/utilities
    $ diff auto.conf my.conf
    17c17
    < ENABLE_BINARY=False
    ---
    > ENABLE_BINARY=True
    22a23
    > LAUNCHPAD_BRANCH=r2.20

    $ ./task.sh my.conf
