#! /bin/bash
# 
# test_network_simple.sh
#
# Set up a couple of test VMs on two networks on a single
# node setup
#
# uses localrc-single
#


set -ex

die() {
    echo "ERROR: " "$@" >&2
    exit 1
}

. ./openrc admin demo

# allow ping and ssh
nova secgroup-list
if ! nova secgroup-list-rules default | grep tcp | grep 22; then
    nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
fi
if ! nova secgroup-list-rules default | grep icmp | grep "\-1"; then
    nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
fi
nova secgroup-list-rules default

# net1
eval $(neutron net-create -f shell -c id net1 | sed -ne '/^id=/p')
net1_id=$id
echo "net1_id=$net1_id"
neutron subnet-create --name net1-subnet1 $net1_id 10.1.0.0/24

# net2 (cloud)
eval $(neutron net-create -f shell -c id net2 | sed -ne '/^id=/p')
net2_id=$id
echo "net2_id=$net2_id"
neutron subnet-create --name net2-subnet1 $net2_id 10.2.0.0/24

# if the net_policy_join script exists, then use it to join net1 and net2
# use ${BASH_SOURCE[0]} instead of $0, because it works when this script is sourced
THIS_DIR=$(dirname ${BASH_SOURCE[0]})
PATH=$THIS_DIR:$PATH
if which net_policy_join.py; then
    net_policy_join.py $net1_id $net2_id 
fi


# stock image form vms
image=cirros-0.3.2-x86_64-uec # default stock image

yes | ssh-keygen -N "" -f sshkey
nova keypair-add --pub-key sshkey.pub sshkey

flavor=m1.tiny
vmargs="--image $image --flavor $flavor --key-name sshkey"

# vm1: net1
nova boot $vmargs --nic net-id=$net1_id vm1

# vm2: net2
nova boot $vmargs --nic net-id=$net2_id vm2

# allow VM to come up
sleep 2

# show where the vms ended up
nova list --fields name,status,Networks,OS-EXT-SRV-ATTR:host

set +ex
