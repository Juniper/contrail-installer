contrail-installer
==================

contrail-installer is a set of scripts and utilities to quickly 
build, install, configure and deploy OpenContrail. It can be used
with pre-build packages (e.g. Launchpad PPA) or from sources. It
is typically used in conjunction with devstack.

# Versions

The contrail-installer master branch generally points to trunk versions 
of OpenContrail components, whether sources or snapshots.  For older, 
stable versions, use appropriate release name. For example:

    cd contrail-installer
    git checkout R1.06 (release 1.06)

Currently contrail-installer supports the following:

    Release 1.06 packages (use git checkout R1.06)
    mainline snapshots (contrail-installer master branch)
    mainline sources (contrail-installer master branch)

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

USE_SCREEN - Set this to True to launch contrail modules in a screen session called
"contrail". Connect to screen session for any troubleshooring of contrail modules.

LOGFILE - Specifiy logfile for contrail.sh runs. By default this is log/contrail.log
in contrail-installer directory

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
    # git checkout R1.06 (if using released 1.06 packages)
    cp samples/localrc-all localrc (edit localrc as needed)
    ./contrail.sh build
    ./contrail.sh install
    ./contrail.sh configure
    ./contrail.sh start

# OpenContrail+Devstack

R1.06 and trunk of contrail-installer currently work with stable/havana, 
stable/icehouse and trunk of devstack.

    git clone git@github.com:openstack-dev/devstack
    
A glue file is needed in the interim till it is upstreamed to devstack

    cp ~/contrail-installer/devstack/lib/neutron_plugins/opencontrail lib/neutron_plugins/

Use a sample localrc:

    cp ~/contrail-installer/devstack/samples/localrc-all localrc

Run stack.sh

    cd devstack
    git checkout stable/havana
    (edit localrc as needed - physical interface, host ip ...)
    ./stack.sh

# Restarting OpenContrail+Devstack

If you need to restart OpenContrail or Devstack for some reason, currently they
need to be synchonized. So

    cd ~/devstack
    ./unstack.sh
    cd ~/contrail-installer
    ./contrail.sh stop

    cd ~/contrail-installer
    ./contrail.sh start
    cd ~/devstack
    ./stack.sh
