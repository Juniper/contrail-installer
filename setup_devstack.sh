DEVSTACK_CLONE_URL="https://github.com/openstack-dev/devstack.git"
DEVSTACK_CLONE_BRANCH=""
CONTRAIL_DIR=`pwd`
DEVSTACK_CLONE_DIR=$CONTRAIL_DIR/../
DEVSTACK_DIR=$DEVSTACK_CLONE_DIR/devstack
RECLONE=${RECLONE:-False}

#echo $RECLONE

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
fi     
cd $CONTRAIL_DIR


if [[ -f $DEVSTACK_DIR/lib/neutron_thirdparty/contrail ]]; then
    echo "file already exist"
else
    cp contrail $DEVSTACK_DIR/lib/neutron_plugins/
fi
cd $CONTRAIL_DIR

if [[ -f $DEVSTACK_DIR/localrc ]]; then
    echo "localrc is already new"
else
    cp samples/localrc-multinode-server $DEVSTACK_DIR/localrc
fi

function replace_in_file()
{
    file=$1
    regexp=$2
    replace=$3
    sed -in 's|.*\b'"$regexp"'.*\b|'"$replace"'|g' $file
}

file=$DEVSTACK_DIR/stackrc

sudo grep -q  ^"CONTRAIL_GIT_BASE" $file
value=$?
if [[ $value -eq 1 ]]; then
    sed -i '206 a\CONTRAIL_GIT_BASE=${CONTRAIL_GIT_BASE:-https://github.com/juniper}\'  $file
fi    
replace_in_file $file "NEUTRON_REPO" "#NEUTRON_REPO"
replace_in_file $file "NEUTRON_BRANCH" "#NEUTRON_BRANCH"
sudo grep -q  ^"NEUTRON_REPO" $file
value=$?
if [[ $value -eq 1 ]]; then
    sed -i '207 a\NEUTRON_REPO=${NEUTRON_REPO:-${CONTRAIL_GIT_BASE}/neutron.git}\'  $file
    sed -i '208 a\NEUTRON_BRANCH=${CONTRAIL_NEUTRON_BRANCH:-contrail/havana}\'  $file
fi

