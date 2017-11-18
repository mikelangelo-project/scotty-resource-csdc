from OpenStackAccess import OpenStack
import yaml


with open("OpenStackConfig.yaml", 'r') as ymlfile:
    cfg = yaml.load(ymlfile)

access = {
    'auth_url': cfg['access']['auth_url'],
    'username': cfg['access']['username'],
    'password': cfg['access']['password'],
    'tenant_name': cfg['access']['tenant_name'],
    'project_name': cfg['access']['project_name']
}
openstack = OpenStack(**access)
openstack._setup()
print openstack._nova.servers.list(search_opts={'all_tenants': '1'})
