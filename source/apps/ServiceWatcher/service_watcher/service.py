import logging

GLOBAL = 0
SHARED = 1

class JobEventHandle(object):
    def __init__(self, service, handler):
        super(JobEventHandle, self).__init__()
        self.service = service
        self.handler = handler

    def __enter__(self):
        self.service.add_job_event_handler(self.handler)

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.service.remove_job_event_handler(self.handler)

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

        # Setup handlers
        self.job_event_handlers = [self.default_job_event_handler]

    def get_unit(self):
        return self.systemd_client.get_unit_by_name(self.unit_name)

    def setup_systemd(self, systemd_client):
        self.systemd_client = systemd_client

    def default_job_event_handler(self, job_id, job_object_path, status):
        logging.info("on_job_event %d %s %s %s" % (job_id, job_object_path, self.unit_name, status))
        logging.info(" -> unit is currently %s" % self.get_unit().ActiveState)

    def on_job_event(self, job_id, job_object_path, status):
        for handler in self.job_event_handlers:
            handler(job_id, job_object_path, status)

    def add_job_event_handler(self, handler):
        self.job_event_handlers.append(handler)

    def remove_job_event_handler(self, handler):
        self.job_event_handlers.remove(handler)

    def handler(self, handler):
        return JobEventHandle(self, handler)

    def initialize(self):
        unit = self.get_unit()
        state = unit.ActiveState

        if state == 'failed':
            logging.info("init: resetting failed state of %s" % self.name)
            unit.ResetFailed()
        elif state != 'inactive':
            logging.warning("init: unexpected initial state for %s: %s" % (self.name, state))

    def terminate(self):
        unit = self.get_unit()
        state = unit.ActiveState

        if state == 'active':
            logging.info("terminate: stopping %s" % self.name)
            unit.Stop("fail")
        elif state != 'inactive':
            logging.warning("terminate: unexpected final state for %s: %s" % (self.name, state))