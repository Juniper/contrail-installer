#! /bin/bash
# 
# test_network_simple.sh
#
# Set up a couple of test VMs on two networks on a single
# node setup
#
# uses localrc-single
#


CLONE_DIR=${CLONE_DIR:-`pwd`}
WITH_CONTRAIL_CLONE=${WITH_CONTRAIL_CLONE:-True}
NETWORK_NAME=${NETWORK_NAME:-net}
SUBNET_NAME=${SUBNET_NAME:-subnet}
SUBNET_CIDR=${SUBNET_CIDR:-11.0.0.0/24}
TENANT_NAME=${TENANT_NAME:-demo}
VM1_IP=${VM1_IP:-11.0.0.2}
VM2_IP=${VM2_IP:-11.0.0.3}
VM_USER=${VM_USER:-cirros}
VM_PASSWORD=${VM_PASSWORD:-cubswin:)}
#CLONE_DIR=`pwd`
_CONTRAIL_NEUTRON_SERVICES=("apiSrv" "schema" "svc-mon") 
#source $DEVSTACK_DIR/openrc $TENANT_NAME $TENANT_NAME

echo "$CONTRAIL_DIR"
if [[ -f $DEVSTACK_DIR/openrc ]] ; then
    source $DEVSTACK_DIR/openrc $TENANT_NAME $TENANT_NAME
else
    echo "Invalid devstack directory please set DEVSTACK_DIR and try again"
fi
#report generation variables
test_cases=("ServiceStatus" "ServiceRequest" "NeutronRequest" "VmCreation" "SimpleGateway" "PingBeweenVms")

status_flags=("NOTEXECUTED" "NOTEXECUTED" "NOTEXECUTED" "NOTEXECUTED" "NOTEXECUTED" "NOTEXECUTED")

log_file_name=("Opencontrail_services_status" "Opencontrail_services_response" "Opencontrail_neutron_requests" "Opencontrail_vm_communication_status" "Opencontrail_simplegateway_status" "Opencontrail_vm_communication" )

function security_group_rules()
{
    # allow ping and ssh
    nova secgroup-list
    if ! nova secgroup-list-rules default | grep tcp | grep 22; then
        nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
    fi
    if ! nova secgroup-list-rules default | grep icmp | grep "\-1"; then
        nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    fi
    nova secgroup-list-rules default
}

function network_creation(){
    
    net=$1
    subnet=$net-$2
    subnet_cidr=$3
    report_file=$CLONE_DIR/sanity_status/Opencontrail_neutron_requests 
    if [[ -f $report_file ]]; then
        rm $report_file
    fi 
    touch $report_file
    eval $(neutron net-create -f shell -c id net | sed -ne '/^id=/p')
    net_id=$id
    #echo "net_id=$net_id" >> $report_file
    if [[ $net_id ]]; then
        echo "--------------------------------------" >> $report_file
        echo "network created successfully net_id=$net_id " >> $report_file
        echo "---------------------------------------" >> $report_file
        subnet_args="$subnet $net $subnet_cidr"
        echo $subnet_args
        subnet_request=$(subnet_creation $subnet_args) 
        echo "$subnet_request" >> $report_file
       
    fi
}

function subnet_creation()
{
    subnet_args=$@
    echo $subnet_args
    neutron subnet-create --name $subnet_args
}

function get_branch()
{
    path=$1
    if [[ -d $path ]] ; then
        cd $path
        branch=$(git status|grep "On branch"|awk '{print $4}')
        echo $branch
    fi
    
}

function get_platform()
{
    platform=$(lsb_release -a |grep "Description" | awk '{print $2,$3,$4}')  
    echo $platform

}

function network_delete()
{
    network=$1
    list=(`neutron net-list|grep "$network"|awk '{print $2}'`)
    for net in ${list[@]} 
    do
        neutron net-delete $net
    done
}

function network_list()
{
    network=$1
    neutron net-list | grep -i "$network"
    #status=$?
    network_creation_request=$?
    #echo $status 
}

function check_network()
{
    network=$1
    network_list $network
    #status=$?
    #echo $status
}

function launch_vm(){

    
    vm_name=$1
    report_file=$2
    image=cirros-0.3.1-x86_64-uec
    flavor=m1.nano
    vmargs="--image $image --flavor $flavor --key-name sshkey"

    yes | ssh-keygen -N "" -f sshkey
    keypairs=$(nova keypair-add --pub-key sshkey.pub sshkey) 
    echo "$keypairs" >> $report_file

    
    nova boot $vmargs --nic net-id=$net_id $vm_name >> $report_file

    
}

function check_vm_status()
{
    vm_name_index=3
    report_file=$1
    vm_status_index=$(($vm_name_index+1))
    vm_network_index=$(($vm_network_index+1))
    vm_ip=(`nova list --fields name,status,Networks|awk '{print $4,$6,$8}'`)
    while [[ $vm_name_index -le ${#vm_ip[@]} ]]
    do
        vm_name=${vm_ip[$vm_name_index]}
        vm_name_index=$((vm_name_index+1))
        vm_status=${vm_ip[$vm_name_index]}
        vm_name_index=$((vm_name_index+1))
        vm_network_ip=${vm_ip[$vm_name_index]}
        vm_name_index=$((vm_name_index+1))
        if [[ $vm_name ]] || [[ $vm_status ]] || [[ $vm_network_ip ]]; then
            echo "----------------------------------------" >> $report_file
            echo "             VM DETAILS" >> $report_file
            echo "----------------------------------------" >> $report_file
            echo "vm name:$vm_name" >> $report_file
            echo "vm status:$vm_status" >> $report_file
            echo "vm network:$vm_network_ip" >> $report_file
         
            if [[ "$vm_status" = "ACTIVE" ]] ; then
                echo "TESTCASE : VMCREATION $vm_name 		-- PASSED"
                status_flags[3]="PASSED"
            else
                echo "TESTCASE : VMCREATION $vm_name            -- FAILED"
                status_flags[3]="FAILED"
            fi
        fi
     
    done
    echo ${vm_ip[@]} 
}

function check_service_stop()
{
    _array="${!1}"
    return_status="start"
    report_file=$CLONE_DIR/sanity_status/Opencontrail_services_status
    for service in $_array[@]
    do  
        status=(`grep -e "$service" $report_file |awk '{print $3}'`)
  
        if [[ "$status" = "ERROR" ]]; then
            return_status="stop"
        fi
    done
    echo "$return_status"
}

function start_sanity_script()
{
    mkdir -p $CLONE_DIR/sanity_status
    
    contrail_service_running_report
    status=$(check_service_stop $_CONTRAIL_NEUTRON_SERVICES)
    echo "$status"
    if [[ "$status" = "start" ]]; then
        services_respose
        network_creation $NETWORK_NAME $SUBNET_NAME $SUBNET_CIDR
        check_network $net
        echo "RETURN STATUS::"$network_creation_request
        if [[ $network_creation_request -eq 0 ]] ; then
            status_flags[2]="PASSED"   
            report_file=$CLONE_DIR/sanity_status/Opencontrail_vm_communication_status
            if [[ -f $report_file ]] ; then
                rm $report_file
            fi

            launch_vm vm1 $report_file
            launch_vm vm2 $report_file
            sleep 30
            check_vm_status $report_file
 
            sudo iptables --flush
            sleep 15
            simplegateway_report_file=$CLONE_DIR/sanity_status/Opencontrail_simplegateway_status
            if [[ -f $report_file ]] ; then
                rm $simplegateway_report_file
            fi

            ping -c 3 $VM1_IP >> $simplegateway_report_file 
            vm1_status=$? 
            ping -c 3 $VM2_IP >> $simplegateway_report_file
            vm2_status=$?
            if [[ $vm1_status -eq 0 ]] && [[ $vm2_status -eq 0 ]] ; then
                status_flags[4]="PASSED"
                install_ping_requirements
                ping_vms $VM1_IP $VM2_IP
                
            else
                echo "TESTCASE : SIMPLE GATEWAY			-- FAILED " 
                status_flags[4]="FAILED"
            fi

        else
            echo "TESTCASE : NETWORK CREATION		-- FAILED"
            status_flags[2]="FAILED"
        fi
            
    else
        echo "CONTRAIL SERVICE ${_CONTRAIL_NEUTRON_SERVICES[@]} are not running please check the status" >> $CLONE_DIR/sanity_status/final_sanity_report
        status
    fi    
    final_sanity_script
}   

function check_array_value()
{
    _array="${!1}"
    #echo "$_array"
    _value=$2
    status="not found"
    for value in ${_array[@]} 
    do
        service_name=$(echo "$value" | awk 'BEGIN {FS=OFS="."}{print $1}')
             
        if [[ "$service_name" = "$_value" ]] ; then
            status="found"
        fi
    done
    echo $status 
}

function contrail_service_running_report()
{
    report_file=$CLONE_DIR/sanity_status/Opencontrail_services_status
    report_error_file=$CLONE_DIR/sanity_status/Opencontrail_services_errors
      
    if [[ -f $report_file ]]; then
        rm $report_file
        
    fi
    touch $report_file 
    touch $report_error_file
    if [[ -d $CONTRAIL_DIR/status/contrail ]]; then
        cd $CONTRAIL_DIR/status/contrail/
        services=(`ls *.pid`)
        failures=(`ls *.failure`) 
        line="----------------------------------------------------------------"
        space="                     "
         
        for service in ${services[@]} 
        do
            
            service_name=$(echo "$service" | awk 'BEGIN {FS=OFS="."}{print $1}')
            _status=$(check_array_value failures[@] $service_name)   
            if [[ "$_status" = "found" ]] ; then
                echo "$line" >> $report_error_file
                printf '%-20s : ERROR\n' $service_name >> $report_file
                printf '%-20s : ERROR\n' $service_name >> $report_error_file
                echo "$line" >> $report_error_file
                echo "ERROR : `tail -n 50 $CONTRAIL_DIR/log/screens/screen-$service_name.log`"  >> $report_error_file
                echo "$line" >> $report_error_file
                
            else
                printf '%-20s : ACTIVE\n' $service_name >> $report_file
            fi
        done
        cat $report_error_file >> $report_file
        rm $report_error_file
        #echo $errors 
    fi
    status_flags[0]="PASSED" 
}

function services_respose()
{
    report_file=$CLONE_DIR/sanity_status/Opencontrail_services_response
    line="----------------------------------------------------------------"
    space="                     "
    if [[ -f $report_file ]]; then
        rm $report_file
    fi
    touch $report_file 
    if [[ -d $CONTRAIL_DIR/status/contrail ]]; then
        cd $CONTRAIL_DIR/status/contrail/
        services=(`ls *.pid`)
    fi
    curl -H "GET" "http://localhost:8082/domains"
    #curl -H "GET" http://localhost:8082/instance-ips

    if [[ $? -eq 0 ]] ; then
        status_flags[1]="PASSED"
    else
        status_flags[1]="FAILED"
    fi
    for service in ${services[@]} 
    do
        service_name=$(echo "$service" | awk 'BEGIN {FS=OFS="."}{print $1}')
        if [[ -f $CONTRAIL_DIR/log/screens/screen-$service_name.log ]]; then
            echo "$line" >> $report_file
            echo "service :  $service_name " >> $report_file  
            echo "$line" >> $report_file
         
            echo "Start : `tail -n 50 $CONTRAIL_DIR/log/screens/screen-$service_name.log`"  >> $report_file
            echo "$line" >> $report_file
        fi                       
    done                   
    
}

function get_contail_installation()
{
    grep_variable=$1
    filename=$2
    return_value="False"
    if [[ -f $filename ]]; then
        return_value=$(grep "$grep_variable" $filename |awk 'BEGIN{FS=OFS="="}{print $2}')
    fi
    if [[ "$return_value" = "True" ]] ; then
        echo "Binary installation"
    else
        echo "Source installation"
    fi   
}

function final_sanity_script()
{
    cd $CLONE_DIR/sanity_status
    final_report_file=./final_report_file
    if [[ -f $final_report_file ]] ; then
        rm $final_report_file
    fi
    file_name=$CLONE_DIR/.report.txt
    touch $final_report_file
    index=0
    platform=$(get_platform) 
    devstack_branch=$(get_branch $DEVSTACK_DIR)
    contrail_branch=$(get_branch $CONTRAIL_DIR)
    report_generation_date=$(date | awk '{print $1,$3,$2,$6}')
    report_generation_time=$(date | awk '{print $4,$5 }') 
    contrail_installation_type=$(get_contail_installation "CONTRAIL_DEFAULT_INSTALL=True" $CONTRAIL_DIR/localrc)
    echo -e "----------------------------------------------------------------" >> $final_report_file
    echo -e "\t\t\tSANITY REPORT" >> $final_report_file
    echo -e "----------------------------------------------------------------" >> $final_report_file
    echo -e "PLATFORM\t\t:\t$platform" >> $final_report_file
    echo -e "CONTRAIL-INSTALLATION\t:\t$contrail_installation_type" >> $final_report_file
    echo -e "CONTRAIL-BRANCH\t\t:\t$contrail_branch" >> $final_report_file
    echo -e "DEVSTACK-BRANCH\t\t:\t$devstack_branch" >> $final_report_file
    echo -e "REPORT-DATE\t\t:\t$report_generation_date" >> $final_report_file
    echo -e "REPORT-TIME\t\t:\t$report_generation_time" >> $final_report_file
    echo -e "----------------------------------------------------------------" >> $final_report_file


    for test_case in ${test_cases[@]}
    do 
        if [[ -f $CLONE_DIR/report_generation.py ]]; then 
            if [[ "${status_flags[$index]}" = "PASSED" ]] || [[ "${status_flags[$index]}" = "NOTEXECUTED" ]] ; then
                python $CLONE_DIR/report_generation.py --testcase $test_case --status ${status_flags[$index]} --FILE $file_name finalreport
            else
                python $CLONE_DIR/report_generation.py --testcase $test_case --status ${status_flags[$index]} --log_path ${log_file_name[$index]} --FILE $file_name finalreport
            fi    
            index=$((index+1))
        fi
    done
    if [[ -f $CLONE_DIR/report_generation.py ]]; then 
        python $CLONE_DIR/report_generation.py --FILE $file_name display >> $final_report_file
        rm $file_name
    fi
    echo -e "NOTE:\tSanity log reports placed under $CLONE_DIR/sanity_status/ " >> $final_report_file
    cat $final_report_file
}

function install_ping_requirements
{
    sudo apt-get install sshpass
    sudo apt-get install expect
}
function ping_vms() { 
    sleep 20
    report_file=$CLONE_DIR/sanity_status/Opencontrail_vm_communication  
    if [[ -f $report_file ]]; then
        rm $report_file
    fi
    touch $report_file  
    source_ip=$1     
    destination_ip=$2  
    rm ~/.ssh/known_hosts
expect -c " 
   set timeout 1
   spawn ssh $VM_USER@$source_ip
   expect yes/no { send yes\r ; exp_continue }
   expect password: { send $VM_PASSWORD\r }
   expect $ { send exit \r }
"
   sshpass -p $VM_PASSWORD ssh -x $VM_USER@$source_ip " ping -c 3 $destination_ip;echo $? " >> $report_file
   status=$? 
   if [[ $status -eq 0 ]]; then
       status_flags[5]="PASSED"
       echo "TESTCASE	PING FROM $source_ip TO $destination_ip  	: 	PASSED" >> $report_file
   else
       status_flags[5]="FAILED"
       echo "TESTCASE	PING FROM $source_ip TO $destination_ip    :       FAILED" >> $report_file
   fi
}
