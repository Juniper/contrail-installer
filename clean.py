#clean database
from vnc_api.vnc_api import VncApi
def main():
    client=VncApi()
    virtual_networks=client.virtual_networks_list()
    virtual_machine_interfaces=client.virtual_machine_interfaces_list()
    virtual_machines=client.virtual_machines_list()
    for virtual_network in virtual_networks['virtual-networks']:
        if 'default-domain:default-project' in (':'.join(virtual_network['fq_name'])):
	    continue
	client.virtual_network_delete(id=virtual_network['uuid'])
    for virtual_machine_interface in virtual_machine_interfaces['virtual-machine-interfaces']:
	client.virtual_machine_interface_delete(id=virtual_machine_interface['uuid'])
    for virtual_machine in virtual_machines['virtual-machines']:
	client.virtual_machine_delete(id=virtual_machine['uuid'])
if __name__=='__main__':
	main()
