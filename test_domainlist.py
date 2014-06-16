from vnc_api.vnc_api import VncApi
def main():
    client=VncApi()
    virtual_networks=client.virtual_networks_list()
    virtual_machine_interfaces=client.virtual_machine_interfaces_list()
    virtual_machines=client.virtual_machines_list()
    instance_ips=client.instance_ips_list()
    projects=client.projects_list()
    domains=client.domains_list()
    floating_ip_pools=client.floating_ip_pools_list()
    access_control_lists=client.access_control_lists_list()
    print domains
    for project in projects['projects']:
        id=project['uuid']
        name=project['fq_name']
        print id,name
    print projects
    print virtual_networks
    print virtual_machine_interfaces
    print virtual_machines
    print instance_ips
    print  access_control_lists
    print  floating_ip_pools
    
             
    
    
    
if __name__=='__main__':
	main()
