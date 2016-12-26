import logging

GLOBAL = 0
SHARED = 1
MULTI = 2

class JobEventHandle(object):
    def __init__(self, service, handler, parameter = None):
        super(JobEventHandle, self).__init__()
        self.service = service
        self.handler = handler
        self.parameter = parameter

    def __enter__(self):
        self.service.add_job_event_handler(self.handler, self.parameter)

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.service.remove_job_event_handler(self.handler, self.parameter)

class Service(object):
    def __init__(self, service_spec):
        super(Service, self).__init__()
        self.systemd_client = None

        # Names for this service
        self.name = service_spec['name']

        # Type of service
        try:
            if service_spec['type'] == 'global':
                self.type = GLOBAL
            elif service_spec['type'] == 'shared':
                self.type = SHARED
            elif service_spec['type'] == 'multi':
                self.type = MULTI
            else:
                raise ValueError("invalid service type %s for %s" % (service_spec['type'], self.name))
        except KeyError:
            # Guess a reasonable default
            if 'count' in service_spec:
                self.type = SHARED
            elif 'instances' in service_spec:
                self.type = MULTI
            else:
                self.type = GLOBAL

        # Setup handlers
        if self.type != MULTI:
            self.unit_name = self.name + '.service'
            self.job_event_handlers = [self.default_job_event_handler]
        else:
            self.job_event_handlers = {'': [self.default_job_event_handler_param]}

        # Read SHARED service properties
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

        # Read MULTI service properties
        if self.type == MULTI:
            try:
                self.instances = {}
                for k, v in service_spec['instances'].iteritems():
                    self.instances[str(k)] = int(v)
            except ValueError:
                raise ValueError("invalid instances specification for %s" % self.name)

        logging.info("discovered type %d service %s" % (self.type, self.name))

    def get_unit(self, parameter = None):
        if self.type == MULTI:
            if parameter is None:
                raise ValueError("parameter must be provided for multi service %s" % self.name)
            return self.systemd_client.get_unit_by_name("%s@%s.service" % (self.name, parameter))
        else:
            return self.systemd_client.get_unit_by_name(self.unit_name)

    def setup_systemd(self, systemd_client):
        self.systemd_client = systemd_client

    def default_job_event_handler(self, job_id, job_object_path, status):
        logging.debug("on_job_event %d %s %s %s, unit is currently %s" %
                      (job_id, job_object_path, self.unit_name, status, self.get_unit().ActiveState))

    def default_job_event_handler_param(self, job_id, job_object_path, status, parameter):
        logging.debug("on_job_event %d %s %s %s, unit is currently %s" %
                      (job_id, job_object_path, "%s@%s" % (self.name, parameter), status, self.get_unit(parameter).ActiveState))

    def on_job_event(self, job_id, job_object_path, job_unit_fn_without_ext, status):
        if self.type == MULTI:
            base_name, param = job_unit_fn_without_ext.split("@", 2)

            # Invoke default handlers
            if '' in self.job_event_handlers:
                # noinspection PyTypeChecker
                for handler in self.job_event_handlers['']:
                    handler(job_id, job_object_path, status, param)

            # Invoke specific handlers
            if param in self.job_event_handlers:
                # noinspection PyTypeChecker
                for handler in self.job_event_handlers[param]:
                    handler(job_id, job_object_path, status)
        else:
            for handler in self.job_event_handlers:
                # noinspection PyCallingNonCallable
                handler(job_id, job_object_path, status)

    def add_job_event_handler(self, handler, parameter = None):
        if self.type == MULTI:
            key = '' if parameter is None else parameter

            if not key in self.job_event_handlers:
                self.job_event_handlers[key] = []

            self.job_event_handlers[key].append(handler)
        else:
            self.job_event_handlers.append(handler)

    def remove_job_event_handler(self, handler, parameter = None):
        if self.type == MULTI:
            key = '' if parameter is None else parameter
            self.job_event_handlers[key].remove(handler)
        else:
            self.job_event_handlers.remove(handler)

    def handler(self, handler, parameter = None):
        return JobEventHandle(self, handler, parameter)

    def initialize(self):
        if self.type == MULTI:
            for k in self.instances:
                self.initialize_unit(self.get_unit(k), "%s@%s" % (self.name, k))
        else:
            self.initialize_unit(self.get_unit(), self.name)

    def initialize_unit(self, unit, name):
        state = unit.ActiveState
        if state == 'failed':
            logging.info("init: resetting failed state of %s" % name)
            unit.ResetFailed()
        elif state != 'inactive':
            logging.warning("init: unexpected initial state for %s: %s" % (name, state))

    def terminate(self):
        if self.type == MULTI:
            for k in self.instances:
                self.terminate_unit(self.get_unit(k), "%s@%s" % (self.name, k))
        else:
            self.terminate_unit(self.get_unit(), self.name)

    def terminate_unit(self, unit, name):
        state = unit.ActiveState
        if state == 'active':
            logging.info("terminate: stopping %s" % name)
            unit.Stop("fail")
        elif state != 'inactive':
            logging.warning("terminate: unexpected final state for %s: %s" % (name, state))