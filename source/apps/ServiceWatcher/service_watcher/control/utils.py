import logging
import os

from gi.repository import GLib

from service_watcher.control.party import SWParty
from service_watcher.prestart import RetryExecute

KNOWN_PARTIES = ["active", "inactive", "failed", "activating", "deactivating"]


class ServiceLogic(object):
    def __init__(self, zk, name, service, unit, control_root):
        super(ServiceLogic, self).__init__()
        self.name = name
        self.service = service
        self.unit = unit
        self.control_root = control_root

        # Group membership for this service object
        self.parties = {}
        for party in KNOWN_PARTIES:
            def logmeth(msg, party):
                return None if party.endswith("ing") else lambda p: logging.info(msg % (self.name, party))
            self.parties[party] = SWParty(zk, "/service_watcher/%s/%s" % (party, self.name),
                                          joined=logmeth("%s: now %s", party),
                                          left=logmeth("%s: not %s anymore", party))

        self.should_run = None
        self.last_state = None

        # Restore state of prestart
        self.retry_later_notified = False
        if self.service.prestart is not None:
            self.service.prestart.load_state(os.path.join(self.control_root.tmpdir, "%s.yml" % self.name))

    def set_should_run(self, value):
        self.should_run = value

    def is_failed(self):
        return (self.last_state or self.try_get_state()) == "failed"

    def try_get_state(self):
        state = None
        try:
            # Fetch current state of service from systemd
            state = self.unit.ActiveState
        except GLib.Error:
            logging.error("%s: failed getting state from systemd" % self.name)
        self.last_state = state
        return state

    def tick(self):
        state = self.try_get_state()

        # Update party membership
        for party in KNOWN_PARTIES:
            if party == state:
                self.parties[party].join()
            else:
                self.parties[party].leave()

        # Only take a decision if we know the current state of the service and what we should do
        if state is not None:
            self.actions(state)

    def actions(self, state=None):
        # noinspection PyBroadException
        try:
            if state is None:
                state = self.unit.ActiveState

            if self.should_run is not None:
                # only do something if we know what to do

                if state == "active":
                    # the service is running
                    if not self.should_run:
                        # the service should not be running, issue stop
                        self.stop_service()
                    else:
                        # check if there is an update to input parameters
                        if self.service.prestart is not None and \
                            self.service.prestart.is_dirty(self.control_root.instance_resolver_root):
                            logging.info("%s: prestart script state is not up-to-date, restarting service" % self.name)
                            self.stop_service()
                    pass
                # ignoring state "reloading", transient
                elif state == "inactive":
                    # the service is stopped
                    if self.should_run:
                        # the service should be running, issue start
                        self.start_service()
                    pass
                elif state == "failed":
                    # the service is failed
                    pass
                elif state == "activating":
                    # the service is trying to start
                    pass
                elif state == "deactivating":
                    # the service is trying to stop
                    pass
        except:
            logging.error("%s: failed controlling the service" % self.name)

    def terminate(self, reload_mode):
        # Save prestart state
        if self.service.prestart is not None:
            self.service.prestart.save_state(os.path.join(self.control_root.tmpdir, "%s.yml" % self.name))

        # If the service is running
        state = self.try_get_state()
        if state == "active" or state == "activating":
            # the service is currently running
            if reload_mode:
                logging.info("%s: keeping service running for reload" % self.name)
            else:
                self.stop_service()
        elif state == "failed":
            # the service has failed
            if reload_mode:
                logging.warning("%s: resetting failed status for reload" % self.name)
                self.unit.ResetFailed()
            else:
                logging.warning("%s: exiting with failed status" % self.name)

    def start_service(self):
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

        if prestart_cb():
            logging.info("%s: starting service" % self.name)
            self.unit.Start("fail")

    def stop_service(self):
        logging.info("%s: stopping service" % self.name)
        self.unit.Stop("fail")
