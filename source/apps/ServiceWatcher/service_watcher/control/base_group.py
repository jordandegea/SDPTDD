import threading


class ControlGroup(object):
    def __init__(self, control_root, service):
        super(ControlGroup, self).__init__()
        # Root controller for this group
        self.control_root = control_root
        # The service definition for this control group
        self.service = service
        # this attribute is to be set by child instances
        # but we cannot pass it to the constructor as this induces a circular dependency
        self.unit = None

    def prestart(self):
        self.unit.prestart()

    def start(self):
        self.unit.start()

    def stop(self):
        self.unit.stop()


class ControlUnit(threading.Thread):
    def __init__(self, control_group, name):
        super(ControlUnit, self).__init__(name=name)
        # Parent control group
        self.control_group = control_group
        # Loop event, to throttle on events
        self.loop_event = threading.Event()

    def prestart(self):
        pass

    def stop(self):
        # Unblock the event loop
        self.release_loop()
        # Wait for the thread to terminate
        self.join()

    def release_loop(self):
        self.loop_event.set()

    def loop_tick(self, timeout=None):
        # Wait for the loop event to be set
        if self.loop_event.wait(timeout):
            # Reset the event
            self.loop_event.clear()

    def get_unit(self, param=None):
        return self.control_group.service.get_unit(param)

    # noinspection PyUnusedLocal
    def job_event_handler(self, job_id, job_object_path, status):
        self.release_loop()
