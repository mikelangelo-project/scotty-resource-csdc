#! /usr/bin/env python
import logging
import os
from fabric.api import put, run as fabric_run, settings
from HeatStack import HeatStack

logger = logging.getLogger(__name__)


def ssh_to(root_path, private_key, remote_server, user, **args):
    logging.info("\n# Swarm Manager IP address is : " + remote_server)
    with settings(host_string=remote_server, key_filename=private_key, user=user):
        fabric_run(
            '[ -d ~/benchmark/cs-datacaching ] || mkdir -p ~/benchmark/cs-datacaching')
        put(root_path + '/asset/', '~/benchmark/cs-datacaching/')
        fabric_run('sudo chmod 750 ~/benchmark/cs-datacaching/asset/prepare.sh')
        fabric_run('echo "[+] Installing SNAP ....."')
        fabric_run(
            'sudo curl -s https://packagecloud.io/install/repositories/intelsdi-x/snap/script.deb.sh | sudo bash')
        fabric_run('sudo apt-get install -y snap-telemetry')
        fabric_run('sudo service snap-telemetry restart')
        fabric_run('sudo mkdir -p /var/log/benchmark')
        fabric_run('sudo chmod 777 /var/log/benchmark/')
        fabric_run(
            'sudo echo -e "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0\n" >> /var/log/benchmark/detail.csv')
        fabric_run("cd ~/benchmark/cs-datacaching/asset && ./prepare.sh " +
                   args['server_no'] + " " +
                   args['server_threads'] + " " +
                   args['memory'] + " " +
                   args['object_size'])


def get_root_path():
    root_path = os.path.dirname(__file__)
    return root_path


def get_heat_args(params):
    root_path = get_root_path()
    stack_abs_path = os.path.join(root_path, params['stack_template'])
    heat_args = {
        'auth_url': params['OpenStack_auth_url'],
        'username': params['OpenStack_username'],
        'password': params['OpenStack_password'],
        'tenant_name': params['OpenStack_tenant_name'],
        'project_name': params['OpenStack_project_name'],
        'stack_name': params['experiment_name'],
        'key_name': params['experiment_name'],
        'number_of_node': params['stack_server_no'],
        'template': stack_abs_path
    }
    return heat_args


def get_benchmark_args(params):
    benchmark_args = {
        'server_no': params['server_no'],
        'server_threads': params['server_threads'],
        'memory': params['memory'],
        'object_size': params['object_size']
    }
    return benchmark_args


def deploy(context):
    resource = context.v1.resource.config
    params = resource['params']
    heat_args = get_heat_args(params)
    benchmark_args = get_benchmark_args(params)
    stack = HeatStack(**heat_args)
    stack.create()
    ip = stack.get_manager_ip()
    root_path = get_root_path()
    instances_names = stack.get_all_instances()
    endpoint = {
        'swarm_manager': {'ip': ip,
                          'user': 'cloud',
                          'private_key': os.path.join('/tmp/', params['experiment_name'], 'private.key'),
                          },
        'instances': instances_names,

    }
    ssh_to(
        root_path,
        endpoint['swarm_manager']['private_key'],
        endpoint['swarm_manager']['ip'],
        endpoint['swarm_manager']['user'],
        **benchmark_args
    )
    return endpoint


def clean(context):
    resource = context.v1.resource.config
    params = resource['params']
    heat_args = get_heat_args(params)
    stack = HeatStack(**heat_args)
    stack.delete()
