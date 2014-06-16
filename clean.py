#clean database
import pycassa
import pycassa.cassandra.ttypes
from pycassa.system_manager import *
import ConfigParser
from cfgm_common.zkclient import ZookeeperClient, IndexAllocator
import gevent.event
import logging
import logging.handlers

def main():
    #removing config_db_uuid,useragent keyspaces
    config = None
    server_list = []
    config = ConfigParser.SafeConfigParser({'admin_token': None})
    config.read('/etc/contrail/contrail-api.conf')
    server_list_str=config.get('DEFAULTS','cassandra_server_list')
    server_list=server_list_str.split()
    server_idx = 0
    num_dbnodes = len(server_list)
    connected = False
    cass_server = None
    while not connected:
       try:
           cass_server = server_list[server_idx]
           sys_mgr = SystemManager(cass_server)
           connected = True
       except Exception as e:
           server_idx = (server_idx + 1) % num_dbnodes
           time.sleep(3)
    
    uuid_keyspace_name = 'config_db_uuid'
    agent_keyspace_name = 'useragent'
    try:
        print "deleting config_db_uuid keyspace"                
        sys_mgr.drop_keyspace(uuid_keyspace_name)
    except pycassa.cassandra.ttypes.InvalidRequestException as e:
        print "Warning! " + str(e)
    try:
        print "deleting useragent keyspace"                 
        sys_mgr.drop_keyspace(agent_keyspace_name)
    except pycassa.cassandra.ttypes.InvalidRequestException as e:
        print "Warning! " + str(e)
    
    #deleting znodes
    _SUBNET_PATH = "/api-server/subnets"
    _FQ_NAME_TO_UUID_PATH = "/fq-name-to-uuid"
    _zk_client = None
    while True:
            try:
                _zk_client = ZookeeperClient("api-" + '0', '127.0.0.1:2181')
                break
            except gevent.event.Timeout as e:
                pass
    print "deleting nodes at ",_SUBNET_PATH
    _zk_client.delete_node(_SUBNET_PATH, True);
    print "deleting nodes at ",_FQ_NAME_TO_UUID_PATH
    _zk_client.delete_node(_FQ_NAME_TO_UUID_PATH, True);
if __name__=='__main__':
	main()

