#!/bin/bash
    
echo -e "Devstack Branch you want to setup: \n [ex: stable/havana]"

read dvstk
    
    
DEVSTACK_CLONE_URL="https://github.com/openstack-dev/devstack.git"
DEVSTACK_CLONE_BRANCH="$dvstk"
CONTRAIL_DIR=`pwd`
DEVSTACK_CLONE_DIR=$CONTRAIL_DIR/../
DEVSTACK_DIR=$DEVSTACK_CLONE_DIR/devstack
RECLONE=${RECLONE:-False}
    
#echo $RECLONE
    
Clone_Devstack () {
    if [ "$RECLONE" = "True" ]; then
        echo "Removing the current devstack and recloning again"
        sudo rm -r $DEVSTACK_DIR
    fi
    if [ -d $DEVSTACK_DIR ]; then
        echo "devstack is already cloned using that devstack to work"
    else
        if [ $DEVSTACK_CLONE_BRANCH ];then
            echo "cloning the branch $DEVSTACK_CLONE_BRANCH"
            CLONE_BRANCH="-b $DEVSTACK_CLONE_BRANCH"
        fi
        cd $DEVSTACK_CLONE_DIR 
        git clone $CLONE_BRANCH $DEVSTACK_CLONE_URL
    fi     
    
}
    
Changes_Devstack_localrc () {
    cd $CONTRAIL_DIR
    
    #checks if there is devstack folder cloned or not
    if [ -d $DEVSTACK_DIR ] ; then
        if [ -f $DEVSTACK_DIR/lib/neutron_plugins/opencontrail ]; then
            echo "opencontrail plugin file is already new in devstack"
        else
            cp $CONTRAIL_DIR/devstack/lib/neutron_plugins/opencontrail $DEVSTACK_DIR/lib/neutron_plugins/
        fi
        if [ -f $DEVSTACK_DIR/localrc ]; then
            echo "localrc is already new"
        else
            cp  $CONTRAIL_DIR/devstack/samples/localrc-all $DEVSTACK_DIR/localrc
        fi
        cd $DEVSTACK_DIR
        if [ -f $DEVSTACK_DIR/localrc ]; then	
            # Changes in $DEVSTACK_DIR/localrc
            sed -i '/ADMIN_PASSWORD/ a USE_SCREENS=True' $DEVSTACK_DIR/localrc
            grep -q "Q_PLUGIN=opencontrail" $DEVSTACK_DIR/localrc
            [ $? -eq 1 ] && sed -i '/ADMIN_PASSWORD/ a Q_PLUGIN=opencontrail' $DEVSTACK_DIR/localrc
            sed -i 's/^#*GIT_BASE/GIT_BASE/g' $DEVSTACK_DIR/localrc
            sed -i 's/^#*NOVA_VIF_DRIVER/NOVA_VIF_DRIVER/g' $DEVSTACK_DIR/localrc
            sed -i "s/^HOST_IP=.*/HOST_IP=`ifconfig | head -n2 | tail -1 | cut -d: -f2 | cut -d' ' -f1`/" $DEVSTACK_DIR/localrc
            if [ -f $CONTRAIL_DIR/localrc ] ; then
                ENABLE_BINARY=`grep "CONTRAIL_DEFAULT_INSTALL" $CONTRAIL_DIR/localrc | cut -d'=' -f2`
         
                #Changes regarding Q_PLUGIN
                if [ "$ENABLE_BINARY" = "True" ]; then
                    [ `grep "^ *LAUNCHPAD_BRANCH=PPA" $CONTRAIL_DIR/localrc` ] && sed -i "s/.*Q_PLUGIN_CLASS=neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_core.NeutronPluginContrailCoreV2.*/#Q_PLUGIN_CLASS=neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_core.NeutronPluginContrailCoreV2/" ./localrc || sed -i "s/.*#Q_PLUGIN_CLASS=neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_core.NeutronPluginContrailCoreV2.*/Q_PLUGIN_CLASS=neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_core.NeutronPluginContrailCoreV2/" ./localrc
                else
                    sed -i "s/.*Q_PLUGIN_CLASS=neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_core.NeutronPluginContrailCoreV2.*/#Q_PLUGIN_CLASS=neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_core.NeutronPluginContrailCoreV2/" ./localrc
                fi
            fi
        fi
    
    fi
    
}
    
Setup_Devstack () {

    Clone_Devstack                    #Cloning devstack into the directory where contrail-installer presents 
    Changes_Devstack_localrc          #Changing localrc in devstack
}
    
Setup_Devstack

echo "Devstack $dvstk : setup completed successfully"    
    
