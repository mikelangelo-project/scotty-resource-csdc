#!/usr/bin/env python

import logging
from keystoneauth1 import loading
from keystoneauth1 import session
import keystoneclient.v2_0.client
import neutronclient.v2_0.client
import heatclient.client
import cinderclient.client
import novaclient.client
import glanceclient.client

logger = logging.getLogger(__name__)


class OpenStack(object):

    def __init__(self, **kwargs):
        for key, value in kwargs.items():
            setattr(self, key, value)

    def _setup(self):
        self._loader = loading.get_plugin_loader('password')
        try:
            self._auth = self._loader.load_from_options(
                auth_url=self.auth_url,
                username=self.username,
                password=self.password,
                project_name=self.project_name)
        except Exception, e:
            logger.error(str(e))

        self._sess = session.Session(auth=self._auth)
        self._heat = heatclient.client.Client('1', session=self._sess)
        self._nova = novaclient.client.Client('2', session=self._sess)
        self._neutron = neutronclient.v2_0.client.Client(session=self._sess)
        self._cinder = cinderclient.client.Client('2', session=self._sess)
        self._glance = glanceclient.client.Client('2', session=self._sess)
        self._keyston = keystoneclient.client.Client('2', session=self._sess)
