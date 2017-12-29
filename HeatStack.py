#! /usr/bin/env python

import logging
import os
import shutil
from time import sleep

from Crypto.PublicKey import RSA

from OpenStackAccess.OpenStackAccess import OpenStack

logger = logging.getLogger(__name__)


class HeatStack(object):

    def __init__(self, **kwargs):

        for key, value in kwargs.items():
            setattr(self, "_" + key, value)
        if not self._template:
            self._template = "heat/default_stack.yaml"
        if not self._number_of_node:
            self._number_of_node = 1
        self._manager_ip = ""
        self._key = RSA.generate(2048)
        self._openstack_vars = {
            'auth_url': self._auth_url,
            'username': self._username,
            'password': self._password,
            'tenant_name': self._tenant_name,
            'project_name': self._project_name}

    def _init_openstack_access(self):
        self._openstack = OpenStack(**self._openstack_vars)
        self._openstack._setup()

    def _init_openstack_stack_args(self):
        template_content = open(self._template, 'r')
        openstack_stack_args = {
            'stack_name': self._stack_name,
            'parameters': {
                'key_name': self._key_name,
                'number_of_node': self._number_of_node},
            'template': template_content.read(),
        }
        template_content.close()
        return openstack_stack_args

    def _store_private_key(self, path_name):
        if not os.path.exists("/tmp/" + path_name):
            os.makedirs("/tmp/" + path_name)
        with open("/tmp/" + path_name + "/private.key", 'w') as content_file:
            os.chmod("/tmp/" + path_name + "/private.key", 0600)
            content_file.write(self._key.exportKey('PEM'))

    def _store_public_key(self, path_name):
        if not os.path.exists("/tmp/" + path_name):
            os.makedirs("/tmp/" + path_name)
        pubkey = self._key.publickey()
        with open("/tmp/" + path_name + "/public.key", 'w') as content_file:
            content_file.write(pubkey.exportKey('OpenSSH'))

    def create_openstack_keypair(self):
        try:
            logger.info("[+] Creating Keypair...")
            output = self._openstack._nova.keypairs.create(
                self._key_name, self._key.publickey().exportKey('OpenSSH'))
            logger.debug(output)
        except Exception as e:
            logger.error(str(e))

    def _delete_openstack_keypair(self, path_name):
        try:
            logger.info("[+] Deleting Keypair...")
            output = self._openstack._nova.keypairs.delete(self._key_name)
            shutil.rmtree("/tmp/" + path_name)
            logger.debug(output)
        except Exception as e:
            logger.error(str(e))

    def check_completed_stack(self):
        while True:
            output = self._openstack._heat.stacks.get(self._stack_name)
            logger.debug(output)
            if output.stack_status == "CREATE_COMPLETE":
                logger.info("[+] Stack CREATE completed successfully ")
                self._manager_ip = output.outputs[0]['output_value']
                break

            if output.stack_status == "CREATE_FAILED":
                logger.error("[X] Stack CREATE FAILED")
                logger.error("[X] Check stack logs")
                break

    def create_keypair(self):
        self._store_private_key(self._stack_name)
        self._store_public_key(self._stack_name)
        self.create_openstack_keypair()

    def create_openstack_stack(self):
        openstack_stack_args = self._init_openstack_stack_args()
        try:
            logger.info("[+] Creating Stack...")
            output = self._openstack._heat.stacks.create(
                **openstack_stack_args)
            logger.debug(output)
            logger.info("[!] Creating stack takes few minutes")
            self.check_completed_stack()
        except Exception as e:
            logger.error(str(e))

    def delete_keypair(self):
        self._delete_openstack_keypair(self._stack_name)

    def delete_openstack_stack(self):
        logger.info("[+] Deleting Stack ...")
        try:
            self._openstack._heat.stacks.delete(self._stack_name)
            sleep(5)
            for i in xrange(1, 11):
                try:
                    result = self._openstack._heat.stacks.get(
                        self._stack_name)
                    if result and (
                            result.stack_status == "DELETE_IN_PROGRESS"):
                        sleep(3)
                        continue
                    elif result and (
                            result.stack_status == "DELETE_FAILED"):
                        logger.info("[I] attemp to delete stack".format(i))
                        result = self._openstack._heat.stacks.delete(
                            self._stack_name)
                        sleep(5)
                        if result and (
                                result.stack_status == "DELETE_FAILED"):
                            logger.error(
                                "[X] {} attemp to delete stack failed".format(i))
                            break
                    else:
                        logger.info("[I] Undefined condition")
                        logger.info("[I] Condition: " + result)
                except Exception as e:
                    logger.info("[+] Stack successfully deleted")
                    break

        except Exception as e:
            logger.error(str(e))

    def create(self):
        self._init_openstack_access()
        self.create_keypair()
        self.create_openstack_stack()

    def get_manager_ip(self):
        output = self._openstack._heat.stacks.get(self._stack_name)
        self._manager_ip = output.outputs[0]['output_value']
        return self._manager_ip

    def delete(self):
        self._init_openstack_access()
        self.delete_keypair()
        self.delete_openstack_stack()

    def get_resources(self):
        return self._openstack._heat.resources.list(self._stack_name)

    def get_all_instances(self):
        instance_list = []
        instances = self._openstack._nova.servers.list(self._stack_name)
        for instance in instances:
            if self._stack_name in instance.name:
                instance_list.append(instance.name)

        return instance_list
