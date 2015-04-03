#!/bin/bash
###############################################################################################################
#
# This script can be used for auto build or CI to perform opencontrail and devstack single node installation.
# Sanity Report will be generated after the installation 
#
# Date:25-sep-2014
#
###############################################################################################################

CLONE_DIR=${CLONE_DIR:-`pwd`} 
ENABLE_BINARY=${ENABLE_BINARY:-False}
WITH_CONTRAIL_CLONE=${WITH_CONTRAIL_CLONE:-True}
ENABLE_CI=${ENABLE_CI:-False}
DEVSTACK_CLONE_URL=${DEVSTACK_CLONE_URL:-"https://github.com/openstack-dev/devstack.git"}
DEVSTACK_CLONE_BRANCH=${DEVSTACK_CLONE_BRANCH:-"stable/icehouse"}
RECLONE=${RECLONE:-False}
run_sanity=${run_sanity:-False}      
NETWORK_NAME=${NETWORK_NAME:-net}
SUBNET_NAME=${SUBNET_NAME:-subnet} 
SUBNET_CIDR=${SUBNET_CIDR:-11.0.0.0/24}
TENANT_NAME=${TENANT_NAME:-demo}

# error codes
_RETURN_STATUS=0
CLONE_ERR_CODE=500
BUILD_ERR_CODE=100
INSTALL_ERR_CODE=200
START_ERR_CODE=300
STACK_ERR_CODE=400
KEYBOARD_INTERUPT=700



function set_environment()
{
    if [[ "$WITH_CONTRAIL_CLONE" = "False" ]]; then
        CONTRAIL_CLONE_DIR=`pwd`
        CONTRAIL_DIR=$CONTRAIL_CLONE_DIR/../../contrail-installer
        DEVSTACK_CLONE_DIR=$CONTRAIL_DIR/..
        DEVSTACK_DIR=$DEVSTACK_CLONE_DIR/devstack   
    else
        CONTRAIL_CLONE_DIR=$CLONE_DIR
        CONTRAIL_DIR=$CLONE_DIR/contrail-installer
        DEVSTACK_CLONE_DIR=$CLONE_DIR
        DEVSTACK_DIR=$DEVSTACK_CLONE_DIR/devstack
    fi
}

function replace_localrc_bin_master()
{
    if [[ ! -f localrc ]]; then
        cp samples/localrc-all ./localrc
        #sed -i "s/.*SERVICE_HOST=localhost.*/SERVICE_HOST=$IP/" ./localrc 
        sed -i "s/.*# CONTRAIL_REPO_PROTO=https.*/CONTRAIL_REPO_PROTO=https/" ./localrc
        echo "USE_SCREENS=True" >> ./localrc
    fi
}

function replace_localrc_source_master()
{
    if [[ ! -f localrc ]]; then
        cp samples/localrc-all ./localrc
        #sed -i "s/.*SERVICE_HOST=localhost.*/SERVICE_HOST=$IP/" ./localrc 
        sed -i "s/.*# CONTRAIL_REPO_PROTO=https.*/CONTRAIL_REPO_PROTO=https/" ./localrc
        sed -i "s/.*CONTRAIL_DEFAULT_INSTALL=True.*/CONTRAIL_DEFAULT_INSTALL=False/" ./localrc
        echo "USE_SCREENS=True" >> ./localrc
    fi
}

function set_localrc()
{
    if [[ -f localrc ]]; then
        rm localrc
    fi
    if [[ "$ENABLE_BINARY" = "True" ]]; then
        replace_localrc_bin_master
    else
        replace_localrc_source_master
    fi
}

function value_check()
{
    value=$1
    if [[ $value == 0 ]]; then
        echo "1"
    fi
    echo "0"

}
function check_start_status()
{   
    source $CONTRAIL_DIR/taskrc`:w
    if [[ -d $CONTRAIL_DIR/status/contrail ]] ; then
        enabled_services_count=$NUM_ENABLED_SERVICES
        pid_count=`ls $CONTRAIL_DIR/status/contrail/*.pid|wc -l`
        if [[ $pid_count -le $enabled_services_count ]]; then
            echo 1
        else
            echo 0
        fi
    else
        echo 1
    fi
}

function run_command()
{
    _command=$1
    cd $CONTRAIL_DIR
    if [[ "$_command" = "start" ]]; then
        ./contrail.sh stop
        if [[ -f $DEVSTACK_DIR/unstack.sh ]] ; then
            dir=`pwd` 
            cd $DEVSTACK_DIR
            ./unstack.sh
            cd $dir
        fi
 
    fi
    
    ./contrail.sh $_command

}

function get_management_ip()
{
    interface=$1
    management_ip=$(ifconfig $interface|grep -e addr| awk 'BEGIN{FS=OFS="net addr"}{print $2}'|awk '{print $1}'|awk 'BEGIN{FS=OFS=":"}{print $2}')
    echo $management_ip

}


function status_return()
{
    _status=$1
    _new_status=$2
    if [[ $_status -eq 0 ]] ; then
        echo $_status 
    else
        echo $_new_status 
    fi
   
}

function get_running_status()
{
    status=$(cat $CONTRAIL_DIR/.stage.txt)
    echo "$status"
}

function ENABLE_CI_changes()
{
    sed -i "s/\(^[' '\t]*\)\(repo_initialize.*\)/\1#\2/g" $CONTRAIL_DIR/contrail.sh
    sed -i "s/\(^[' '\t]*\)\(repo sync.*\)/\1#\2/g"  $CONTRAIL_DIR/contrail.sh
    echo "CONTRAIL_SRC=$CONTRAIL_SRC" >> $CONTRAIL_DIR/localrc
}

function clone_contrail()
{
    
    if [[ ! -d contrail-installer ]]; then 
        if [[ -z $CONTRAIL_INSTALLER_BRANCH ]]; then
            git clone https://github.com/Juniper/contrail-installer
        else
            git clone -b $CONTRAIL_INSTALLER_BRANCH https://github.com/Juniper/contrail-installer
        fi
    fi
    _status=$?
    _RETURN_STATUS=$(status_return $_status $CLONE_ERR_CODE)

}

function add_gateway()
{
    localrc_file=$CONTRAIL_DIR/localrc
    sudo grep -q  ^"CONTRAIL_VGW_INTERFACE" $localrc_file
    value=$?
    if [[ $value -eq 1 ]]; then
    
        echo "CONTRAIL_VGW_INTERFACE=vgw" >> $localrc_file
        echo "CONTRAIL_VGW_PUBLIC_SUBNET=$SUBNET_CIDR" >> $localrc_file
        echo "CONTRAIL_VGW_PUBLIC_NETWORK=default-domain:$TENANT_NAME:$NETWORK_NAME:$NETWORK_NAME" >> $localrc_file
    else
       : 
    fi
}

function start_contrail()
{   if [[ "$WITH_CONTRAIL_CLONE" = "True" ]]; then
        clone_contrail
    fi
    if [[ -d $CONTRAIL_DIR ]] ; then
        cd $CONTRAIL_DIR 
        set_localrc
    
        if [[ "$ENABLE_CI" = "True" ]]; then
            ENABLE_CI_changes
        fi 
     
        if [[ -f $CONTRAIL_DIR/.stage.txt ]]; then
        
            running_status=$(get_running_status)
            if [[ "$running_status" = "Build" ]]; then
                run_command install
                _status=$?
                _RETURN_STATUS=$(status_return $_status $INSTALL_ERR_CODE) 
            elif [[ "$running_status" = "install" ]]; then
                :
            else       
                run_command build
                _status=$?
                _RETURN_STATUS=$(status_return $_status $BUILD_ERR_CODE)
                running_status=$(get_running_status)   
                if [[ "$running_status" = "Build" ]]; then
                    run_command install
                    _status=$?
                    _RETURN_STATUS=$(status_return $_status $INSTALL_ERR_CODE) 
                fi
             fi
        
        else
            run_command build
            _status=$?
            _RETURN_STATUS=$(status_return $_status $BUILD_ERR_CODE)
        
            sleep 5
            
            echo "sleeping for 5 seconds to start install..."
            running_status=$(get_running_status)
            if [[ "$running_status" = "Build" ]]; then
                run_command install
                _status=$?
                _RETURN_STATUS=$(status_return $_status $INSTALL_ERR_CODE)
            else
                echo "Contrail stoped in the build phase please check the issue" 
            fi   
        fi
        sleep 5

        echo "sleeping for 5 seconds to start configure..."

        running_status=$(get_running_status)
        if [[ "$running_status" = "install" ]]; then
            
            add_gateway
            run_command configure
            sleep 5

            echo "sleeping for 5 seconds to start contrail services..."
       
            run_command start
            _status=$(check_start_status)  
            _RETURN_STATUS=$(status_return $_status $START_ERR_CODE)
            sleep 5
        fi
     else
         echo "contrail installation stoped"
     fi
    
}

function unset_creds()
{
    unset https_proxy
    unset http_proxy
    unset ftp_proxy
    unset socks_proxy
    unset no_proxy
}

function start_script()
{
    configuration_file=$1
    #cat $configuration_file
    
    ARGS_COUNT=$#
    #echo $ARGS_COUNT    
    if [[ $ARGS_COUNT -le 1 ]] ; then
        #echo "entered"  
        if [[ "$configuration_file" = "usage" ]] || [[ "$configuration_file" = "--help" ]] || [[ "$configuration_file" = "--h" ]]; then
            echo "     " 
            echo "Usage: ./task.sh [auto.conf]"
            echo "ex: task.sh auto.conf"
            echo "     " 
            echo "auto.conf parameters:"
            echo "----------------------"
            echo "CONTRAIL_INSTALLER_BRANCH : if any specfic branch is to be cloned"
            echo "ENABLE_BINARY : set this value to True or False"  
            echo "DEVSTACK_CLONE_BRANCH : devstack branch to be cloned" 
            echo "ENABLE_CI : set this value to True or False"
            echo "CONTRAIL_SRC : contrail source directory"
            echo "NETWORK_NAME : name of the network to be created"
            echo "SUBNET_NAME : name of the subnet to be created"
            echo "SUBNET_CIDR : subnet CIDR address "
            echo "TENANT_NAME : name of the tenant "

            echo "     "  
            exit 
            
        fi
        if [[ -f $configuration_file ]]; then
            #echo "entered into file"
            source $configuration_file
            set_environment
            #echo $WITH_CONTRAIL_CLONE
            start_contrail
            start_status=$(check_start_status)
            if [[ $start_status -eq 0 ]]; then
                start_devstack
            else
                echo "contrail services are not up and running..please check the services" 
            fi

        else
            if [[ $ARGS_COUNT -eq 0 ]] ; then
                echo "continuing with the default parameters" 
                start_contrail
                start_status=$(check_start_status)
                if [[ $start_status -eq 0 ]]; then
                   start_devstack
                else
                    echo "contrail services are not up and running..please check the services" 
                fi
            else
                echo "       "
                echo "SCRIPT ERROR::  Invalid option please try ./task.sh usage (or) ./task.sh --help (or) ./task.sh --h"
                echo "       "
                exit  
            fi
            
        fi

            
        
    else
        echo "Usage: ./task.sh [auto.conf]"
        echo "ex: task.sh auto.conf"
        echo "     " 
        echo "auto.conf parameters:"
        echo "----------------------"
 
        echo "CONTRAIL_INSTALLER_BRANCH : if any specfic branch is to be cloned"
        echo "ENABLE_BINARY : set this value to True or False"  
        echo "DEVSTACK_CLONE_BRANCH : devstack branch to be cloned" 
        echo "ENABLE_CI : set this value to True or False"
        echo "CONTRAIL_SRC : contrail source directory"
        echo "NETWORK_NAME : name of the network to be created"
        echo "SUBNET_NAME : name of the subnet to be created"
        echo "SUBNET_CIDR : subnet CIDR address "
        echo "TENANT_NAME : name of the tenant "
            
        echo "-----------------------" 
    fi
}

function start_devstack()
{
    cd $CONTRAIL_DIR
    if [[ "$RECLONE" == "True" ]]; then
        echo "Removing the current devstack and recloning again"
        sudo rm -r $DEVSTACK_DIR
    fi
    if [[ -d $DEVSTACK_DIR ]]; then
        echo "devstack is already cloned using that devstack to work"
    else
        if [[ $DEVSTACK_CLONE_BRANCH ]];then
            echo "cloning the branch $DEVSTACK_CLONE_BRANCH"
            CLONE_BRANCH="-b $DEVSTACK_CLONE_BRANCH"
        fi
        cd $DEVSTACK_CLONE_DIR 
        git clone $CLONE_BRANCH $DEVSTACK_CLONE_URL
        _status=$?
        _RETURN_STATUS=$(status_return $_status $CLONE_ERR_CODE) 
    fi     
    cd $CONTRAIL_DIR
    #checks if there is devstack folder cloned or not
    if [[ -d $DEVSTACK_DIR ]] ; then
    
        if [[ -f $DEVSTACK_DIR/lib/neutron_thirdparty/opencontrail ]]; then
            echo "file already exist"
        else
            cp $CONTRAIL_DIR/devstack/lib/neutron_plugins/opencontrail $DEVSTACK_DIR/lib/neutron_plugins/
        fi
        cd $CONTRAIL_DIR

        if [[ -f $DEVSTACK_DIR/localrc ]]; then
            echo "localrc is already new"
        else
            cp  $CONTRAIL_DIR/devstack/samples/localrc-all $DEVSTACK_DIR/localrc
        fi
        cd $DEVSTACK_DIR
        if [[ "$ENABLE_BINARY" = "False" ]]; then 
            sed -i "s/.*Q_PLUGIN_CLASS=neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_core.NeutronPluginContrailCoreV2.*/#Q_PLUGIN_CLASS=neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_core.NeutronPluginContrailCoreV2/" ./localrc
        fi
        HOST_IP=$(get_management_ip vhost0)
        echo "HOST_IP=$HOST_IP" >> ./localrc 
        #./unstack.sh
        ./stack.sh  
        _stack_status=$?
        if [[ "$WITH_CONTRAIL_CLONE" = "False" ]] ; then
            cd $CONTRAIL_DIR/utilities
        else
            cd $CLONE_DIR
        fi
        source sanity.sh
        start_sanity_script
        
        _RETURN_STATUS=$(status_return $_stack_status $STACK_ERR_CODE)
    fi
}

start_script $@
echo "exit code:"$_RETURN_STATUS
exit $_RETURN_STATUS

trap clean SIGINT
clean() {
  
    local r=$KEYBOARD_INTERUPT
    exit $r
}

