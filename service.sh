#! /bin/bash

TOP_DIR=`pwd`
CONTRAIL_USER=$(whoami)
CONTRAIL_SRC=${CONTRAIL_SRC:-/opt/stack/contrail}
source functions
source localrc

function pywhere()
{
    module=$1
    python -c "import $module; import os; print os.path.dirname($module.__file__)"
}
  

function _start_service()
{
    service=$1
    if is_ubuntu; then
        REDIS_CONF="/etc/redis/redis.conf"
        CASS_PATH="/usr/sbin/cassandra"
    else
        REDIS_CONF="/etc/redis.conf"
        CASS_PATH="$CONTRAIL_SRC/third_party/apache-cassandra-2.0.2/bin/cassandra"
    fi
    if [ "$INSTALL_PROFILE" = "ALL" ]; then
        case $service in
            redis) echo "starting redis"
                   redis-cli flushall
                   screen_it redis "sudo redis-server $REDIS_CONF"
                   ;;
 
            cass) echo "starting cassandra"
                  screen_it cass "sudo $CASS_PATH -f"
                   ;;

            zk) echo "starting zookeeper"
                screen_it zk  "cd $CONTRAIL_SRC/third_party/zookeeper-3.4.6; ./bin/zkServer.sh start"

                   ;;

            ifmap) echo "starting ifmap"
                   if [[ "$CONTRAIL_DEFAULT_INSTALL" != "True" ]]; then
                          screen_it ifmap "cd $CONTRAIL_SRC/build/packages/ifmap-server; java -jar ./irond.jar"
                   else
                          screen_it ifmap "cd /usr/share/ifmap-server; java -jar ./irond.jar" 
                   fi
                   ;;

           disco) echo "starting disco"
                  screen_it disco "python $(pywhere discovery)/disc_server_zk.py --reset_config --conf_file /etc/contrail/discovery.conf"
                   ;;

           apisrv) echo "starting apiserver"
                   screen_it apiSrv "python $(pywhere vnc_cfg_api_server)/vnc_cfg_api_server.py --conf_file /etc/contrail/contrail-api.conf  --rabbit_password ${RABBIT_PASSWORD}"
                   ;;
 
           schema) echo "starting schema"
                  screen_it schema "python $(pywhere schema_transformer)/to_bgp.py --reset_config --conf_file /etc/contrail/contrail-schema.conf"
                   ;;
   
           svc-mon) echo "starting svc-mon"
                    screen_it svc-mon "python $(pywhere svc_monitor)/svc_monitor.py --reset_config --conf_file /etc/contrail/svc-monitor.conf"
                   ;;

           control) echo "starting control"
                    if [[ "$CONTRAIL_DEFAULT_INSTALL" != "True" ]]; then
                        screen_it control "export LD_LIBRARY_PATH=/opt/stack/contrail/build/lib; $CONTRAIL_SRC/build/production/control-node/control-node --conf_file /etc/contrail/contrail-control.conf ${CERT_OPTS} ${LOG_LOCAL}"
                    else
                        screen_it control "export LD_LIBRARY_PATH=/usr/lib; /usr/bin/control-node --conf_file /etc/contrail/contrail-control.conf ${CERT_OPTS} ${LOG_LOCAL}"
                    fi
                   ;;

           collector) echo "starting collector"
                 if [[ "$CONTRAIL_DEFAULT_INSTALL" != "True" ]]; then
                    screen_it collector "sudo PATH=$PATH:$TOP_DIR/bin LD_LIBRARY_PATH=/opt/stack/contrail/build/lib $CONTRAIL_SRC/build/production/analytics/vizd"
                 else
                    screen_it collector "sudo PATH=$PATH:/usr/bin LD_LIBRARY_PATH=/usr/lib /usr/bin/contrail-collector"
                 fi
                   ;;
 
          analytics-api) echo "starting analytics-api"
                    screen_it analytics-api "python  $(pywhere opserver)/opserver.py"
                   ;;

          query-engine) echo "starting query-engine"
               if [[ "$CONTRAIL_DEFAULT_INSTALL" != "True" ]]; then  
                   screen_it query-engine "sudo PATH=$PATH:$TOP_DIR/bin LD_LIBRARY_PATH=/opt/stack/contrail/build/lib $CONTRAIL_SRC/build/production/query_engine/qed"
               else
                    screen_it query-engine "sudo PATH=$PATH:/usr/bin LD_LIBRARY_PATH=/usr/lib /usr/bin/contrail-query-engine"
               fi
                   ;;

          agent) echo "starting agent"
                 screen_it agent "sudo $TOP_DIR/bin/vnsw.hlpr"
                   ;;

          redis-w ) echo "starting redis-w "
                   screen_it redis-w "sudo redis-server /etc/contrail/redis-webui.conf"
                   
                   ;;

          ui-jobs) echo "starting ui-jobs"
                   if [[ "$CONTRAIL_DEFAULT_INSTALL" != "True" ]]; then 
                       screen_it ui-jobs "cd /opt/stack/contrail/contrail-web-core; sudo node jobServerStart.js"
                   else
                       screen_it ui-jobs "cd /var/lib/contrail-webui-bundle; sudo node jobServerStart.js"
                   fi
                   ;;

          ui-webs) echo "starting ui-webs"
                   if [[ "$CONTRAIL_DEFAULT_INSTALL" != "True" ]]; then 
                       screen_it ui-webs "cd /opt/stack/contrail/contrail-web-core; sudo node webServerStart.js"
                   else
                       screen_it ui-webs "cd /var/lib/contrail-webui-bundle; sudo node webServerStart.js"
                   fi
           
                   ;;
          *) echo "please verify the service entered"
             ;;
        esac
    else
        case $service in
            agent) echo "starting agent"
                 screen_it agent "sudo $TOP_DIR/bin/vnsw.hlpr"
                   ;;
            *) echo "please verify the service entered in compute mode"
                   ;;
        esac
    fi
            
}

function start_service()
{
    if [[ -f $TOP_DIR/status/contrail/$1.pid ]]; then
        echo "$1 is already running"
        exit
    else
       _start_service $1
    fi      
}

function stop_service()
{
    echo "stopping the service $1"
    screen_stop $1
}

function restart_service()
{
    if [[ -f $TOP_DIR/status/contrail/$1.pid ]]; then
        echo "$1 is already running,stopping it"
        stop_service $1
    fi
    echo "restarting service $1"
    _start_service $1
   
}

OPTION=$2
ARGS_COUNT=$#
if [ "$USE_SCREEN" = "False" ]; then
    if [ $ARGS_COUNT -eq 2 ] && [ "$OPTION" == "start" ] || [ "$OPTION" == "restart" ] || [ "$OPTION" == "stop" ] ; 
    then
        ${OPTION}_service $1
    else
        echo "Usage :: service.sh servicename [option]"
        echo "ex: service.sh servicename start"
        echo "[options]:"
        echo "start"
        echo "stop"
        echo "restart"
    fi
else 
    echo "screens enabled"
fi
