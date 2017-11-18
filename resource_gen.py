#! /usr/bin/env python
import logging
import os
from fabric.api import put, run as fabric_run, settings

from HeatStack import HeatStack

logger = logging.getLogger(__name__)


def ssh_to(root_path, key_path, remote_server, **args):
    logging.info("\n# Swarm Manager IP address is : " + remote_server)
    with settings(host_string=remote_server,
                  key_filename="/tmp/" + key_path +
                  "/private.key", user="cloud"):
        fabric_run(
            '[ -d ~/benchmark/cs-datacaching ] || mkdir -p ~/benchmark/cs-datacaching')
        put(root_path + '/asset/', '~/benchmark/cs-datacaching/')
        put(root_path + '/prepare.sh', '~/benchmark/cs-datacaching/')
        fabric_run('sudo chmod 750 ~/benchmark/cs-datacaching/prepare.sh')
        fabric_run('echo $(hostname) >>  /tmp/exp.txt ')
        fabric_run('echo "[+] Installing SNAP ....."')
        fabric_run(
            'sudo curl -s https://packagecloud.io/install/repositories/intelsdi-x/snap/script.deb.sh | sudo bash')
        fabric_run('sudo apt-get install -y snap-telemetry')
        fabric_run('sudo service snap-telemetry restart')
        fabric_run('sudo mkdir -p /var/log/benchmark')
        fabric_run('sudo chmod 777 /var/log/benchmark/')
        fabric_run(
            'sudo echo -e "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0\n" >> /var/log/benchmark/detail.csv')
        fabric_run('cd ~/benchmark/cs-datacaching/ && ls')
        fabric_run("cd ~/benchmark/cs-datacaching/ && ./prepare.sh " +
                   args['server_no'] + " " +
                   args['server_threads'] + " " +
                   args['memory'] + " " +
                   args['object_size'])

def experiment_path():
    experiment_path = os.path.join(
        os.path.join(os.getcwd(), os.pardir), os.pardir)
    return experiment_path

def get_heat_args(params):
    stack_abs_path = os.path.join(experiment_path(), params['stack_path'])
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
    stack_config_path = experiment_path()
    instances_names = stack.get_all_instances()
    root_path = os.path.join(os.path.dirname(__file__))
    ssh_to(
        root_path,
        params['experiment_name'],
        ip,
        **benchmark_args
    )
    endpoint = {
        'ip': ip,
        'stack_config_path': stack_config_path,
        'instances': instances_names
    }
    return endpoint


def clean(context):
    resource = context.v1.resource.config
    params = resource['params']
    experiment_path = os.path.join(
        os.path.join(os.getcwd(), os.pardir), os.pardir)
    stack_abs_path = os.path.join(experiment_path, params['stack_path'])
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
    stack = HeatStack(**heat_args)
    stack.delete()
