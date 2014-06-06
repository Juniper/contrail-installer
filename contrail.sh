# proto is https or ssh
#! /bin/bash

# Contrail NFV
# ------------

# Save trace setting
MY_XTRACE=$(set +o | grep xtrace)
set -o xtrace
TOP_DIR=`pwd`
source functions
source localrc

BS_FL_CONTROLLERS_PORT=${BS_FL_CONTROLLERS_PORT:-localhost:80}
BS_FL_OF_PORT=${BS_FL_OF_PORT:-6633}

unset LANG
unset LANGUAGE
LC_ALL=C
export LC_ALL

# Set up logging level
VERBOSE=$(trueorfalse True $VERBOSE)
CONTRAIL_REPO_PROTO=${CONTRAIL_REPO_PROTO:-ssh}
CONTRAIL_SRC=${CONTRAIL_SRC:-/opt/stack/contrail}
LOG_DIR=${LOG_DIR:-$TOP_DIR/log/screens}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-contrail123}
CONTRAIL_ADMIN_USERNAME=${CONTRAIL_ADMIN_USERNAME:-admin}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-contrail123}
CONTRAIL_ADMIN_TENANT=${CONTRAIL_ADMIN_TENANT:-admin}
CFGM_IP=${SERVICE_HOST:-127.0.0.1}
if [[ "$CFGM_IP" == "localhost" ]] ; then
    CFGM_IP="127.0.0.1"
fi
USE_CERTS=${USE_CERTS:-false}
MULTI_TENANCY=${MULTI_TENANCY:-false}
PUPPET_SERVER=${PUPPET_SERVER:-''}
CASSANDRA_IP_LIST=${CASSANDRA_IP_LIST:-127.0.0.1}

OPENSTACK_IP=${OPENSTACK_IP:-$CFGM_IP}
COLLECTOR_IP=${COLLECTOR_IP:-$CFGM_IP}
DISCOVERY_IP=${DISCOVERY_IP:-$CFGM_IP}
CONTROL_IP=${CONTROL_IP:-$CFGM_IP}

# Draw a spinner so the user knows something is happening
function spinner() {
    local delay=0.75
    local spinstr='/-\|'
    printf "..." >&3
    while [ true ]; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr" >&3
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b" >&3
    done
}
    
# Echo text to the log file, summary log file and stdout
# echo_summary "something to say"
function echo_summary() {
    if [[ -t 3 && "$VERBOSE" != "True" ]]; then
        kill >/dev/null 2>&1 $LAST_SPINNER_PID
        if [ ! -z "$LAST_SPINNER_PID" ]; then
            printf "\b\b\bdone\n" >&3
        fi
        echo -e $@ >&6
        spinner &
        LAST_SPINNER_PID=$!
    else
        echo -e $@ >&6
    fi
}

# Echo text only to stdout, no log files
# echo_nolog "something not for the logs"
function echo_nolog() {
    echo $@ >&3
}

function setup_logging() { 
    # Set up logging for ``contrail.sh``
    # Set ``LOGFILE`` to turn on logging
    # Append '.xxxxxxxx' to the given name to maintain history
    # where 'xxxxxxxx' is a representation of the date the file was created
    TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"%F-%H%M%S"}
    if [[ -n "$LOGFILE" || -n "$LOG_DIR" ]]; then
        LOGDAYS=${LOGDAYS:-7}
        CURRENT_LOG_TIME=$(date "+$TIMESTAMP_FORMAT")
    fi

    if [[ -n "$LOGFILE" ]]; then
        # First clean up old log files.  Use the user-specified ``LOGFILE``
        # as the template to search for, appending '.*' to match the date
        # we added on earlier runs.
        LOGDIR=$(dirname "$LOGFILE")
        LOGFILENAME=$(basename "$LOGFILE")
        mkdir -p $LOGDIR
        mkdir -p $LOG_DIR
        find $LOGDIR -maxdepth 1 -name $LOGFILENAME.\* -mtime +$LOGDAYS -exec rm {} \;
        LOGFILE=$LOGFILE.${CURRENT_LOG_TIME}
        SUMFILE=$LOGFILE.${CURRENT_LOG_TIME}.summary

        # Redirect output according to config

        # Copy stdout to fd 3
        exec 3>&1
        if [[ "$VERBOSE" == "True" ]]; then
            # Redirect stdout/stderr to tee to write the log file
            exec 1> >( awk '
                    {
                        cmd ="date +\"%Y-%m-%d %H:%M:%S \""
                        cmd | getline now
                        close("date +\"%Y-%m-%d %H:%M:%S \"")
                        sub(/^/, now)
                        print
                        fflush()
                    }' | tee "${LOGFILE}" ) 2>&1
            # Set up a second fd for output
            exec 6> >( tee "${SUMFILE}" )
        else
            # Set fd 1 and 2 to primary logfile
            exec 1> "${LOGFILE}" 2>&1
            # Set fd 6 to summary logfile and stdout
            exec 6> >( tee "${SUMFILE}" >&3 )
        fi

        echo_summary "contrail.sh log $LOGFILE"
        # Specified logfile name always links to the most recent log
        ln -sf $LOGFILE $LOGDIR/$LOGFILENAME
        ln -sf $SUMFILE $LOGDIR/$LOGFILENAME.summary
    else
        # Set up output redirection without log files
        # Copy stdout to fd 3
        exec 3>&1
        if [[ "$VERBOSE" != "True" ]]; then
            # Throw away stdout and stderr
            exec 1>/dev/null 2>&1
        fi
        # Always send summary fd to original stdout
        exec 6>&3
    fi
}

function download_dependencies {
    echo "Downloading dependencies"
    if is_ubuntu; then
        apt_get install patch scons flex bison make vim unzip
        apt_get install libexpat-dev libgettextpo0 libcurl4-openssl-dev
        apt_get install python-dev autoconf automake build-essential libtool
	apt_get install python-lxml
        apt_get install libevent-dev libxml2-dev libxslt-dev
        apt_get install uml-utilities
        apt_get install python-setuptools
        apt_get install curl
        apt_get install chkconfig
    else
        sudo yum -y install patch scons flex bison make vim
        sudo yum -y install expat-devel gettext-devel curl-devel
        sudo yum -y install gcc-c++ python-devel autoconf automake libtool
        sudo yum -y install libevent libevent-devel libxml2-devel libxslt-devel
	sudo yum -y install openssl-devel
        sudo yum -y install tunctl
        sudo yum -y install python-setuptools
        sudo yum -y install python-lxml
        sudo yum -y install curl
        sudo yum -y install chkconfig
    fi

}

function download_python_dependencies {
    echo "Downloading python dependencies"
    # api server requirements
    # sudo pip install gevent==0.13.8 geventhttpclient==1.0a thrift==0.8.0
    # sudo easy_install -U distribute
    pip_install --upgrade setuptools
    pip_install gevent geventhttpclient==1.0a thrift
    pip_install netifaces fabric argparse
    pip_install bottle
    if [ "$INSTALL_PROFILE" = "ALL" ]; then
        if is_ubuntu; then
            apt_get install redis-server
        else
            sudo yum -y install redis
            sudo yum -y install java-1.7.0-openjdk
        fi
        pip_install stevedore xmltodict python-keystoneclient
        pip_install kazoo pyinotify
    fi
}

function repo_initialize {
    echo "Initializing repo"
    if [ ! -d $CONTRAIL_SRC/.repo ]; then
        git config --global --get user.name || git config --global user.name "Anonymous"
        git config --global --get user.email || git config --global user.email "anonymous@nowhere.com"
        if [ "$CONTRAIL_REPO_PROTO" == "ssh" ]; then
            if [ $CONTRAIL_BRANCH ];then
                repo init -u git@github.com:Juniper/contrail-vnc -b $CONTRAIL_BRANCH
                rev_original="refs\/heads\/master"
                rev_new="refs\/heads\/"$CONTRAIL_BRANCH 
	            sed -i "s/$rev_original/$rev_new/" .repo/manifest.xml
            else
                repo init -u git@github.com:Juniper/contrail-vnc 
            fi
        else
            if [ $CONTRAIL_BRANCH ];then
                repo init -u https://github.com/Juniper/contrail-vnc -b $CONTRAIL_BRANCH
                rev_original="refs\/heads\/master"
                rev_new="refs\/heads\/"$CONTRAIL_BRANCH 
	            sed -i "s/$rev_original/$rev_new/" .repo/manifest.xml
            else
                repo init -u https://github.com/Juniper/contrail-vnc 
            fi
            sed -i 's/fetch=".."/fetch=\"https:\/\/github.com\/Juniper\/\"/' .repo/manifest.xml
        fi
    fi
}

function download_cassandra {
    echo "Downloading cassanadra"
    if ! which cassandra > /dev/null 2>&1 ; then
        if is_ubuntu; then
            apt_get install python-software-properties
            sudo -E add-apt-repository -y ppa:nilarimogard/webupd8
            apt_get update
            apt_get install launchpad-getkeys

            # use oracle Java 7 instead of OpenJDK
            sudo -E add-apt-repository -y ppa:webupd8team/java
            apt_get update
            echo debconf shared/accepted-oracle-license-v1-1 select true | \
            sudo debconf-set-selections
            echo debconf shared/accepted-oracle-license-v1-1 seen true | \
            sudo debconf-set-selections
            yes | apt_get install oracle-java7-installer

            # See http://wiki.apache.org/cassandra/DebianPackaging
            echo "deb http://www.apache.org/dist/cassandra/debian 12x main" | \
            sudo tee /etc/apt/sources.list.d/cassandra.list
            gpg --keyserver pgp.mit.edu --recv-keys F758CE318D77295D
            gpg --export --armor F758CE318D77295D | sudo apt-key add -
            gpg --keyserver pgp.mit.edu --recv-keys 2B5C1B00
            gpg --export --armor 2B5C1B00 | sudo apt-key add -

            apt_get update
            apt_get install --force-yes cassandra

            # fix cassandra's stack size issues
            test_install_cassandra_patch

            # don't start cassandra at boot.  I'll screen_it later
            sudo service cassandra stop
            sudo update-rc.d -f cassandra remove
        elif [ ! -d $CONTRAIL_SRC/third_party/apache-cassandra-2.0.2-bin ]; then
            contrail_cwd=$(pwd)
            cd $CONTRAIL_SRC/third_party
            wget http://repo1.maven.org/maven2/org/apache/cassandra/apache-cassandra/2.0.2/apache-cassandra-2.0.2-bin.tar.gz
            tar xvzf apache-cassandra-2.0.2-bin.tar.gz
            cd ${contrail_cwd}
        fi
    fi
}

function download_zookeeper {
    echo "Downloading zookeeper"
    if [ ! -d $CONTRAIL_SRC/third_party/zookeeper-3.4.5 ]; then
        contrail_cwd=$(pwd)
        cd $CONTRAIL_SRC/third_party
        wget http://apache.mirrors.hoobly.com/zookeeper/stable/zookeeper-3.4.6.tar.gz
        tar xvzf zookeeper-3.4.6.tar.gz
        cd zookeeper-3.4.6
        cp conf/zoo_sample.cfg conf/zoo.cfg
        cd ${contrail_cwd}
    fi
}

function download_ncclient {
    # ncclient
    echo "Downloading ncclient"
    if ! python -c 'import ncclient' >/dev/null 2>&1; then
        contrail_cwd=$(pwd)
        cd $CONTRAIL_SRC/third_party
        wget https://code.grnet.gr/attachments/download/1172/ncclient-v0.3.2.tar.gz
        pip_install ncclient-v0.3.2.tar.gz
        cd ${contrail_cwd}
    fi
}

function build_contrail() {

    validstage_atoption "build"
    [[ $? -eq 1 ]] && invalid_option_exit "build"

    echo "doing build_contrail"
    echo_summary "doing build_contrail "
    
    C_UID=$( id -u )
    C_GUID=$( id -g )
    sudo mkdir -p /var/log/contrail
    sudo chown $C_UID:$C_GUID /var/log/contrail

    # basic dependencies
    if ! which repo > /dev/null 2>&1 ; then
	wget http://commondatastorage.googleapis.com/git-repo-downloads/repo
        chmod 0755 repo
	sudo mv repo /usr/bin
    fi

    #checking whether previous execution stage of script is at started then
    #only allow to get the dependencies
    if [[ $(read_stage) == "started" ]]; then
    # dependencies
        download_dependencies
        change_stage "started" "Dependencies"
    fi
   
    source install_pip.sh
    /bin/bash install_pip.sh
        
    if [[ $(read_stage) == "Dependencies" ]]; then
        download_python_dependencies
        change_stage "Dependencies" "python-dependencies"
    fi

    sudo mkdir -p $CONTRAIL_SRC
    sudo chown $C_UID:$C_GUID $CONTRAIL_SRC

    THIRDPARTY_SRC=${THIRDPARTY_SRC:-/opt/stack/contrail/third_party}
    sudo mkdir -p $THIRDPARTY_SRC
    sudo chown $C_UID:$C_GUID $THIRDPARTY_SRC

    contrail_cwd=$(pwd)
    cd $CONTRAIL_SRC
    if [[ $(read_stage) == "python-dependencies" ]]; then
        repo_initialize
        change_stage "python-dependencies" "repo-init"
    fi

    if [[ $(read_stage) == "repo-init" ]]; then
        repo sync
        [[ $? -ne 0 ]] && echo "repo sync failed" && exit
        change_stage "repo-init" "repo-sync"
    fi

    if [[ $(read_stage) == "repo-sync" ]]; then
        python third_party/fetch_packages.py
        change_stage "repo-sync" "fetch-packages"
    fi

    (cd third_party/thrift-*; touch configure.ac README ChangeLog; autoreconf --force --install)
    cd $CONTRAIL_SRC
    if [ "$INSTALL_PROFILE" = "ALL" ]; then
        if [[ $(read_stage) == "fetch-packages" ]]; then
            sudo scons --opt=production
            ret_val=$?
            [[ $ret_val -ne 0 ]] && exit
            change_stage "fetch-packages" "Build"
       fi
    elif [ "$INSTALL_PROFILE" = "COMPUTE" ]; then
        if [[ $(read_stage) == "fetch-packages" ]]; then
            sudo scons --opt=production compute-node-install
            ret_val=$?
            [[ $ret_val -ne 0 ]] && exit
            change_stage "fetch-packages" "Build"          
        fi
    else
        echo "Selected profile is neither ALL nor COMPUTE"
        exit
    fi
   
}

function install_contrail() {
    validstage_atoption "install"
    [[ $? -eq 1 ]] && invalid_option_exit "install"

    echo "doing install_contrail"
    echo_summary "doing install_contrail "
    cd $CONTRAIL_SRC
    if [ "$INSTALL_PROFILE" = "ALL" ]; then
        if [[ $(read_stage) == "Build" ]]; then
            sudo scons --opt=production install
            ret_val=$?
            [[ $ret_val -ne 0 ]] && exit
            cd ${contrail_cwd}

            # install contrail modules
            echo "Installing contrail modules"
            pip_install --upgrade $(find $CONTRAIL_SRC/build/production -name "*.tar.gz" -print)

            # install VIF driver
            #pip_install $CONTRAIL_SRC/build/noarch/nova_contrail_vif/dist/nova_contrail_vif*.tar.gz

            # install neutron patch after VNC api is built and installed
            # test_install_neutron_patch

            # get cassandra
            download_cassandra
	    
            # get ifmap
            #download_ifmap_irond
            cd $CONTRAIL_SRC
            make -f packages.make package-ifmap-server  

            download_zookeeper

            # ncclient
            download_ncclient 
            change_stage "Build" "install"
       fi
    elif [ "$INSTALL_PROFILE" = "COMPUTE" ]; then
        if [[ $(read_stage) == "Build" ]]; then
            sudo scons --opt=production compute-node-install
            ret_val=$?
            [[ $ret_val -ne 0 ]] && exit
            cd ${contrail_cwd}

            # install contrail modules
            echo "Installing contrail modules"
            pip_install --upgrade $(find $CONTRAIL_SRC/build/production -name "*.tar.gz" -print)

            # install VIF driver
            #pip_install $CONTRAIL_SRC/build/noarch/nova_contrail_vif/dist/nova_contrail_vif*.tar.gz
            change_stage "Build" "install"         
        fi
    else
        echo "Selected profile is neither ALL nor COMPUTE"
        exit
    fi
    
    echo "finished install_contrail"
    echo_summary "finished install_contrail"
}

function apply_patch() { 
    local patch="$1"
    local dir="$2"
    local sudo="$3"
    local patch_applied="${dir}/$(basename ${patch}).appled"

    # run patch, ignore previously applied patches, and return an
    # error if patch says "fail"
    [ -d "$dir" ] || die "No such directory $dir"
    [ -f "$patch" ] || die "No such patch file $patch"
    if [ -e "$patch_applied" ]; then
	echo "Patch $(basename $patch) was previously applied in $dir"
    else
	echo "Installing patch $(basename $patch) in $dir..."
	if $sudo patch -p0 -N -r - -d "$dir" < "$patch" 2>&1 | grep -i fail; then
	    die "Failed to apply $patch in $dir"
	else
	    sudo touch "$patch_applied"
	    true
	fi
    fi
}

function test_install_cassandra_patch() { 
    apply_patch $TOP_DIR/cassandra-env.sh.patch /etc/cassandra sudo
}

# take over physical interface
function insert_vrouter() {
    source /etc/contrail/contrail-compute.conf
    EXT_DEV=$dev
    if [ -e $VHOST_CFG ]; then
	source $VHOST_CFG
    else
	DEVICE=vhost0
	IPADDR=$(sudo ifconfig $EXT_DEV | sed -ne 's/.*inet *addr[: ]*\([0-9.]*\).*/\1/i p')
	NETMASK=$(sudo ifconfig $EXT_DEV | sed -ne 's/.*mask[: *]\([0-9.]*\).*/\1/i p')
    fi
    # don't die in small memory environments
    sudo insmod $CONTRAIL_SRC/$kmod vr_flow_entries=4096 vr_oflow_entries=512

    echo "Creating vhost interface: $DEVICE."
    VIF=$CONTRAIL_SRC/build/production/vrouter/utils/vif
    DEV_MAC=$(cat /sys/class/net/$dev/address)
    sudo $VIF --create $DEVICE --mac $DEV_MAC \
        || echo "Error creating interface: $DEVICE"

    echo "Adding $DEVICE to vrouter"
    sudo $VIF --add $DEVICE --mac $DEV_MAC --vrf 0 --mode x --type vhost \
	|| echo "Error adding $DEVICE to vrouter"

    echo "Adding $dev to vrouter"
    sudo $VIF --add $dev --mac $DEV_MAC --vrf 0 --mode x --type physical \
	|| echo "Error adding $dev to vrouter"

    if is_ubuntu; then

	# copy eth0 interface params, routes, and dns to a new
	# interfaces file for vhost0
	(
	cat <<EOF
iface $dev inet manual

iface $DEVICE inet static
EOF
	sudo ifconfig $dev | perl -ne '
/HWaddr\s*([a-f\d:]+)/i    && print(" hwaddr $1\n");
/inet addr:\s*([\d.]+)/i && print(" address $1\n");
/Bcast:\s*([\d.]+)/i     && print(" broadcast $1\n");
/Mask:\s*([\d.]+)/i      && print(" netmask $1\n");
'
	sudo route -n | perl -ane '$F[7]=="'$dev'" && ($F[3] =~ /G/) && print(" gateway $F[1]\n")'

	perl -ne '/^nameserver ([\d.]+)/ && push(@dns, $1); 
END { @dns && print(" dns-nameservers ", join(" ", @dns), "\n") }' /etc/resolv.conf
) >/tmp/interfaces

	# bring down the old interface
	# and bring it back up with no IP address
	sudo ifdown $dev
	sudo ifconfig $dev 0 up

	# bring up vhost0
	sudo ifup -i /tmp/interfaces $DEVICE
	echo "Sleeping 10 seconds to allow link state to settle"
	sleep 10
	sudo ifup -i /tmp/interfaces $dev
    else
	echo "Sleeping 10 seconds to allow link state to settle"
	sudo ifup $DEVICE
	sudo cp /etc/contrail/ifcfg-$dev /etc/sysconfig/network-scripts
	sleep 10
	echo "Restarting network service"
	sudo service network restart
    fi
}

function test_insert_vrouter ()
{
    if lsmod | grep -q vrouter; then 
	echo "vrouter module already inserted."
    else
	insert_vrouter
	echo "vrouter kernel module inserted."
    fi
}

function pywhere() {
    module=$1
    python -c "import $module; import os; print os.path.dirname($module.__file__)"
}

function start_contrail() {
   
    # save screen settings
    SAVED_SCREEN_NAME=$SCREEN_NAME
    SCREEN_NAME="contrail"
    screen -d -m -S $SCREEN_NAME -t shell -s /bin/bash
    sleep 1
    # Set a reasonable status bar
    if [ -z "$SCREEN_HARDSTATUS" ]; then
        SCREEN_HARDSTATUS='%{= .} %-Lw%{= .}%> %n%f %t*%{= .}%+Lw%< %-=%{g}(%{d}%H/%l%{g})'
    fi 
    screen -r $SCREEN_NAME -X hardstatus alwayslastline "$SCREEN_HARDSTATUS"
    if [ "$INSTALL_PROFILE" = "ALL" ]; then
        if is_ubuntu; then
            REDIS_CONF="/etc/redis/redis.conf"
            CASS_PATH="/usr/sbin/cassandra"
        else
            REDIS_CONF="/etc/redis.conf"
            CASS_PATH="$CONTRAIL_SRC/third_party/apache-cassandra-2.0.2/bin/cassandra"
        fi

        # launch ...
        redis-cli flushall
        screen_it redis "sudo redis-server $REDIS_CONF"

        screen_it cass "sudo $CASS_PATH -f"

        screen_it zk  "cd $CONTRAIL_SRC/third_party/zookeeper-3.4.6; ./bin/zkServer.sh start"

        screen_it ifmap "cd $CONTRAIL_SRC/third_party/irond-0.3.0-bin; java -jar ./irond.jar"
        sleep 2
    
    
        screen_it disco "python $(pywhere discovery)/disc_server_zk.py --reset_config --conf_file /etc/contrail/discovery.conf"
        sleep 2

        # find the directory where vnc_cfg_api_server was installed and start vnc_cfg_api_server.py
        screen_it apiSrv "python $(pywhere vnc_cfg_api_server)/vnc_cfg_api_server.py --conf_file /etc/contrail/contrail-api.conf  --rabbit_password ${RABBIT_PASSWORD}"
        echo "Waiting for api-server to start..."
        if ! timeout $SERVICE_TIMEOUT sh -c "while ! http_proxy= wget -q -O- http://${SERVICE_HOST}:8082; do sleep 1; done"; then
            echo "api-server did not start"
            exit 1
        fi
        sleep 2
        screen_it schema "python $(pywhere schema_transformer)/to_bgp.py --reset_config --conf_file /etc/contrail/contrail-schema.conf"
        screen_it svc-mon "python $(pywhere svc_monitor)/svc_monitor.py --reset_config --conf_file /etc/contrail/svc-monitor.conf"

        #source /etc/contrail/control_param.conf
        screen_it control "export LD_LIBRARY_PATH=/opt/stack/contrail/build/lib; $CONTRAIL_SRC/build/production/control-node/control-node --conf_file /etc/contrail/contrail-control.conf ${CERT_OPTS} ${LOG_LOCAL}"

        # Provision Vrouter - must be run after API server and schema transformer are up
        sleep 2
        admin_user=${CONTRAIL_ADMIN_USERNAME:-"admin"}
        admin_passwd=${ADMIN_PASSWORD:-"contrail123"}
        admin_tenant=${CONTRAIL_ADMIN_TENANT:-"admin"}
        #changed because control_param.conf is commented
        python $TOP_DIR/provision_vrouter.py --host_name `hostname` --host_ip $CONTROL_IP --api_server_ip $SERVICE_HOST --oper add --admin_user $admin_user --admin_password $admin_passwd --admin_tenant_name $admin_tenant

    fi
    # vrouter
    test_insert_vrouter

    # agent
    if [ $CONTRAIL_VGW_INTERFACE -a $CONTRAIL_VGW_PUBLIC_SUBNET -a $CONTRAIL_VGW_PUBLIC_NETWORK ]; then
        sudo sysctl -w net.ipv4.ip_forward=1
        sudo /opt/stack/contrail/build/production/vrouter/utils/vif --create vgw --mac 00:01:00:5e:00:00
        sudo ifconfig vgw up
        sudo route add -net $CONTRAIL_VGW_PUBLIC_SUBNET dev vgw
    fi
    source /etc/contrail/contrail-compute.conf
    #sudo mkdir -p $(dirname $VROUTER_LOGFILE)
    mkdir -p $TOP_DIR/bin
    
    # make a fake contrail-version when contrail isn't installed by yum
    if ! contrail-version >/dev/null 2>&1; then
	cat >$TOP_DIR/bin/contrail-version <<EOF2
#! /bin/sh
cat <<EOF
Package                                Version                 Build-ID | Repo | RPM Name
-------------------------------------- ----------------------- ----------------------------------
contrail-analytics                     1-1304082216        148                                    
openstack-dashboard.noarch             2012.1.3-1.fc17     updates                                
contrail-agent                         1-1304091654        contrail-agent-1-1304091654.x86_64     
EOF
EOF2
    fi
    chmod a+x $TOP_DIR/bin/contrail-version

    cat > $TOP_DIR/bin/vnsw.hlpr <<END
#! /bin/bash
PATH=$TOP_DIR/bin:$PATH
LD_LIBRARY_PATH=/opt/stack/contrail/build/lib $CONTRAIL_SRC/build/production/vnsw/agent/vnswad --config_file=/etc/contrail/contrail-vrouter-agent.conf --DEFAULT.log_file=/var/log/vrouter.log 
END
    chmod a+x $TOP_DIR/bin/vnsw.hlpr
    screen_it agent "sudo $TOP_DIR/bin/vnsw.hlpr"

    if is_service_enabled q-meta; then
	# set up a proxy route in contrail from 169.254.169.254:80 to
	# my metadata server at port 8775
	python /opt/stack/contrail/controller/src/config/utils/provision_linklocal.py \
	    --linklocal_service_name metadata \
	    --linklocal_service_ip 169.254.169.254 \
	    --linklocal_service_port 80 \
	    --ipfabric_service_ip $Q_META_DATA_IP \
	    --ipfabric_service_port 8775 \
	    --oper add
    fi


    # restore saved screen settings
    SCREEN_NAME=$SAVED_SCREEN_NAME
    return
}

function configure_contrail() {
    validstage_atoption "configure"
    [[ $? -eq 1 ]] && invalid_option_exit "configure"

    echo "doing configure_contrail"
    echo_summary "doing configure_contrail "

    # process gateway configuration if present
    #contrail_gw_interface=""
    # if [ $CONTRAIL_VGW_INTERFACE -a $CONTRAIL_VGW_PUBLIC_SUBNET -a $CONTRAIL_VGW_PUBLIC_NETWORK   ];    then
    #     contrail_gw_interface="--vgw_interface $CONTRAIL_VGW_INTERFACE --vgw_public_subnet $CONTRAIL_VGW_PUBLIC_SUBNET --vgw_public_network $CONTRAIL_VGW_PUBLIC_NETWORK"
    # fi

    # create config files
    # export passwords in a subshell so setup_contrail can pick them up but they won't leak later
    #(export ADMIN_PASSWORD CONTRAIL_ADMIN_USERNAME SERVICE_TOKEN CONTRAIL_ADMIN_TENANT && 
    #python $TOP_DIR/setup_contrail.py --physical_interface=$PHYSICAL_INTERFACE --cfgm_ip $SERVICE_HOST $contrail_gw_interface
    # )

    #defaults loading
    if [[ ! -d "/etc/contrail" ]]; then
        sudo mkdir -p /etc/contrail
        sudo chown `whoami` /etc/contrail
    fi
    cd $TOP_DIR  
    
    #un-comment if required after review
    #KEYSTONE_IP=${KEYSTONE_IP:-127.0.0.1}
    #CONTRAIL_ADMIN_TOKEN=${CONTRAIL_ADMIN_TOKEN:-''}
    
    #all arguments should be added with defaults  

    #all the functions in contrail_config_functions
    source contrail_config_functions

    #invoke functions to change the files
    if [ "$INSTALL_PROFILE" = "ALL" ]; then
        replace_api_server_conf
        replace_contrail_plugin_conf
        replace_contrail_schema_conf
        replace_svc_monitor_conf
        replace_discovery_conf
        replace_vnc_api_lib_conf
        replace_ContrailPlugin_conf
        replace_contrail_control_conf
        replace_dns_conf
        replace_irond_basic_auth_users
    fi	        
    replace_contrail_compute_conf
    replace_contrail_vrouter_agent_conf
    write_ifcfg-vhost0
    write_default_pmac 
    write_qemu_conf
    replace_vizd_param
    replace_qed_param
    fixup_config_files
}

function init_contrail() {
    :
}

function check_contrail() {
    :
}

function clean_contrail() {
    echo_summary "starting clean_contrail"
    python clean.py
    echo_summary "Finished clean_contrail"

}

function stop_contrail() {
    SAVED_SCREEN_NAME=$SCREEN_NAME
    SCREEN_NAME="contrail"
    SCREEN=$(which screen)
    if [[ -n "$SCREEN" ]]; then
        SESSION=$(screen -ls | awk '/[0-9].contrail/ { print $1 }')
        if [[ -n "$SESSION" ]]; then
            screen -X -S $SESSION quit
        fi
    fi
    (cd $CONTRAIL_SRC/third_party/zookeeper-3.4.6; ./bin/zkServer.sh stop)
    if [ "$INSTALL_PROFILE" = "ALL" ]; then
        screen_stop redis
        screen_stop cass
        screen_stop zk
        screen_stop ifmap
        screen_stop disco
        screen_stop apiSrv
        screen_stop schema
        screen_stop svc-mon
        screen_stop control
    fi
    screen_stop agent  
    cmd=$(lsmod | grep vrouter)
    if [ $? == 0 ]; then
        cmd=$(sudo rmmod vrouter)
        if [ $? == 0 ]; then
            source /etc/contrail/contrail-compute.conf
            if is_ubuntu; then
                sudo ifconfig  $dev down
                sleep 10 
                sudo ifdown vhost0
                sudo ifconfig  $dev up
                
            else
                sudo rm -f /etc/sysconfig/network-scripts/ifcfg-$dev
                sudo rm -f /etc/sysconfig/network-scripts/ifcfg-vhost0
            fi
        fi
    fi
    if [ $CONTRAIL_VGW_PUBLIC_SUBNET ]; then
        sudo route del -net $CONTRAIL_VGW_PUBLIC_SUBNET dev vgw
    fi
    if [ $CONTRAIL_VGW_INTERFACE ]; then
        sudo tunctl -d vgw
    fi
    # restore saved screen settings
    SCREEN_NAME=$SAVED_SCREEN_NAME
    return
}

# Kill background processes on exit
trap clean EXIT
clean() {
    local r=$?
    if [[ $r -ne 0 ]]; then
        echo "killing background processes"
        kill >/dev/null 2>&1 $(jobs -p)
    fi
    exit $r
}

#keyboard interrupt

trap interrupt SIGINT
interrupt() {
    local r=$?
    kill >/dev/null 2>&1 $(jobs -p)
    set -o xtrace
    echo "keyboard interrupt"
    exit $r
}

#=================================
[[ $(read_stage) == "nofile" ]] && write_stage "started"
OPTION=$1
ARGS_COUNT=$#
setup_logging
if [ $ARGS_COUNT -eq 1 ] && [ "$OPTION" == "install" ] || [ "$OPTION" == "start" ] || [ "$OPTION" == "configure" ] || [ "$OPTION" == "clean" ] || [ "$OPTION" == "stop" ] || [ "$OPTION" == "build" ]; 
then
    ${OPTION}_contrail
else
    echo "Usage :: contrail.sh [option]"
    echo "ex: contrail.sh install"
    echo "[options]:"
    echo "install"
    echo "start"
    echo "stop"
    echo "configure"
    echo "clean"

fi
# Fin
# ===

if [[ -n "$LOGFILE" ]]; then
    exec 1>&3
    # Force all output to stdout and logs now
    exec 1> >( tee -a "${LOGFILE}" ) 2>&1
else
    # Force all output to stdout now
    exec 1>&3
fi

# Restore xtrace
$MY_XTRACE
