import logging
from gi.repository import GLib

GLOBAL = 0
SHARED = 1

class Service(object):
    def __init__(self, service_spec):
        super(Service, self).__init__()
        self.systemd_client = None

        # Names for this service
        self.name = service_spec['name']
        self.unit_name = self.name + '.service'

        # Type of service
        try:
            if service_spec['type'] == 'global':
                self.type = GLOBAL
            elif service_spec['type'] == 'shared':
                self.type = SHARED
        except KeyError:
            # Default to shared
            self.type = SHARED

        # Find out the count
        if self.type == SHARED:
            try:
                self.count = int(service_spec['count'])
                if self.count <= 0:
                    raise ValueError("invalid count")
            except KeyError:
                # Default to 1
                self.count = 1
            except ValueError:
                raise ValueError("service %s count should be a positive integer" % self.name)

    def get_unit(self):
        return self.systemd_client.get_unit_by_name(self.unit_name)

    def setup_systemd(self, systemd_client):
        self.systemd_client = systemd_client

    def on_job_new(self, job_id, job_object_path):
        logging.info("onJobNew %d %s %s" % (job_id, job_object_path, self.unit_name))
        try:
            job_object = self.systemd_client.get_object(job_object_path)
            logging.info("-> %d %s (%s) %s" % (job_id, job_object.JobType, job_object.State, self.unit_name))
        except GLib.Error:
            logging.error("failed getting job details for %d, unit is currently %s" % (
                job_id, self.get_unit().ActiveState))

    def initialize(self):
        unit = self.get_unit()
        state = unit.ActiveState

        if self.type == GLOBAL:
            # This is a global service, it should be active
            if state == 'active':
                logging.info("init: %s already active, ok" % self.name)
            else:
                logging.info("init: starting global service %s" % self.name)
                unit.Start("fail")
        elif self.type == SHARED:
            # This is a shared service, it should not be active unless we are the leader
            if state == 'active':
                logging.info("init: stopping %s" % self.name)
                unit.Stop("fail")
            elif state == 'failed':
                logging.info("init: resetting failed state of %s" % self.name)
                unit.ResetFailed()
            elif state != 'inactive':
                logging.warning("init: unknown initial state for %s: %s" % (self.name, state))

    def terminate(self):
        unit = self.get_unit()
        state = unit.ActiveState

        if state == 'active':
            logging.info("terminate: stopping %s" % self.name)
            unit.Stop("fail")
        elif state == 'failed':
            logging.info("terminate: resetting failed state of %s" % self.name)
            unit.ResetFailed()
        elif state != 'inactive':
            logging.warning("terminate: unknown final state for %s: %s" % (self.name, state))