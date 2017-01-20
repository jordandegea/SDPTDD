import logging
import os
from socket import gethostname
from gi.repository import GLib
from kazoo.recipe.party import ShallowParty

from service_watcher.prestart import RetryExecute


class ServiceLogic(object):
    def __init__(self, zk, name, service, unit, control_root):
        super(ServiceLogic, self).__init__()
        self.name = name
        self.service = service
        self.unit = unit
        self.control_root = control_root

        # Group membership for this service object
        self.party = ShallowParty(zk, "/service_watcher/active/%s" % self.name, gethostname())
        self.failed_party = ShallowParty(zk, "/service_watcher/failed/%s" % self.name, gethostname())

        self.service_started = False
        self.service_start_initiated = False
        self.service_failed = False
        self.service_stop_initiated = False

        self.should_run = None
        self.joined_scheduled = False

        # Restore state of prestart
        self.retry_later_notified = False
        if self.service.prestart is not None:
            self.service.prestart.load_state(os.path.join(self.control_root.tmpdir, "%s.yml" % self.name))

    def set_should_run(self, value):
        self.should_run = value

    def tick(self):
        state = None
        exit_code = 0

        try:
            state = self.unit.ActiveState
            exit_code = self.unit.ExecMainCode
        except GLib.Error:
            logging.error("%s: failed getting state from systemd" % self.name)

        if exit_code == 143:
            try:
                self.unit.ResetFailed()
            except GLib.Error:
                logging.error("%s: failed resetting failed state of service (143)" % self.name)
            state = "inactive"

        # First step, update current state
        if state == "active":
            if not self.service_started:
                logging.info("%s: service started" % self.name)

                self.party.join()
                self.service_started = True
                self.service_start_initiated = False

            if self.service_failed:
                self.failed_party.leave()
                self.service_failed = False
        elif state == "inactive":
            if self.service_started:
                logging.info("%s: service stopped" % self.name)

                self.party.leave()
                self.service_started = False
                self.service_start_initiated = False
                self.service_stop_initiated = False

            if self.service_failed:
                self.failed_party.leave()
                self.service_failed = False
                self.service_start_initiated = False
                self.service_stop_initiated = False
        elif state == "failed":
            if self.service_started:
                self.party.leave()
                self.service_started = False
                self.service_start_initiated = False
                self.service_stop_initiated = False

            if not self.service_failed:
                logging.warning("%s: service failed, holding off" % self.name)

                self.failed_party.join()
                self.service_failed = True
                self.service_start_initiated = False
                self.service_stop_initiated = False

        # Only take a decision if we know the current state of the service and what we should do
        if state is not None:
            self.actions()

    def actions(self):
        # noinspection PyBroadException
        try:
            self._actions()
        except:
            logging.error("%s: failed controlling the service" % self.name)

    def _actions(self):
        if self.should_run is not None:
            if self.should_run and not self.service_stop_initiated:
                # try having the service running
                if not self.service_started:
                    # run the pre-exec
                    def prestart_cb():
                        if self.service.prestart is not None:
                            try:
                                logging.debug("%s: executing prestart script" % self.name)
                                self.service.prestart.execute(self.control_root.instance_resolver_root)
                                self.retry_later_notified = False
                                return True
                            except RetryExecute:
                                if not self.retry_later_notified:
                                    logging.info("%s: retrying later, missing scheduled instance" % self.name)
                                    self.retry_later_notified = True
                            except Exception as e:
                                logging.error("%s: critical error in prestart script: %s" % (self.name, e))
                        else:
                            return True
                        return False

                    self.start_service(prestart_cb)
                else:
                    if self.service.prestart is not None and \
                            self.service.prestart.is_dirty(self.control_root.instance_resolver_root):
                        logging.info("%s: prestart script state is not up-to-date, restarting service" % self.name)
                        self.stop_service()
            elif self.should_run:
                # try having the service stopped
                if self.service_started:
                    self.stop_service()

    def terminate(self, reload_mode):
        if self.service.prestart is not None:
            self.service.prestart.save_state(os.path.join(self.control_root.tmpdir, "%s.yml" % self.name))

        if self.service_start_initiated or self.service_started:
            # the service is currently running
            if reload_mode:
                logging.info("%s: keeping service running for reload" % self.name)
            else:
                # noinspection PyBroadException
                try:
                    self.stop_service()
                except:
                    logging.error("%s: error stopping service on terminate" % self.name)
        elif self.service_failed:
            # the service has failed
            if reload_mode:
                logging.warning("%s: resetting failed status for reload" % self.name)
                self.unit.ResetFailed()
            elif self.unit.ExecMainCode == 143:
                logging.warning("%s: resetting SIGTERM 143 exit" % self.name)
                self.unit.ResetFailed()
            else:
                logging.warning("%s: exiting with failed status" % self.name)

    def start_service(self, guard=None):
        if not self.service_start_initiated:
            if guard is None or guard():
                logging.info("%s: starting service" % self.name)
                self.unit.Start("fail")
                self.service_start_initiated = True

    def stop_service(self):
        if not self.service_stop_initiated:
            logging.info("%s: stopping service" % self.name)
            self.unit.Stop("fail")
            self.service_stop_initiated = True
