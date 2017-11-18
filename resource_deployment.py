import argparse
from HeatStack import HeatStack
import yaml


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-n', '--name', help='Benchmark name. default: stack', default='stack')
    parser.add_argument(
        '-a', '--action', help='Name of the action. Options: {"create", "delete"}')
    parser.add_argument('-t', '--template',
                        help='Heat template file', default="heat/default_stack.yaml")
    parser.add_argument('-o', '--openstack',
                        help='Open Stack Access file', default="OpenStackAccess/OpenStackConfig.yaml")
    parser.add_argument(
        '-w', '--nodes', help='Number of Swarm worker nodes', default=2)
    args = parser.parse_args()

    with open(args.openstack, 'r') as ymlfile:
        cfg = yaml.load(ymlfile)
    access = {
        'auth_url': cfg['access']['auth_url'],
        'username': cfg['access']['username'],
        'password': cfg['access']['password'],
        'tenant_name': cfg['access']['tenant_name'],
        'project_name': cfg['access']['project_name'],
        'name': args.name,
        'number_of_nodes': args.nodes,
        'template': args.template
    }

    stack = HeatStack(**access)

    if args.action:
        method = getattr(stack, args.action)
        method()
    else:
        parser.print_help()
