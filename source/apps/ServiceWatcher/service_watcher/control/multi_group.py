import json
import logging
from copy import copy
from socket import gethostname

from kazoo.recipe.partitioner import SetPartitioner

from service_watcher import service as svc
from service_watcher.control.base_group import ControlGroup, ControlUnit
from service_watcher.control.utils import ServiceLogic
from service_watcher.prestart import *


class MultiControlGroup(ControlGroup):
    def __init__(self, control_root, service):
        super(MultiControlGroup, self).__init__(control_root, service)
        # Only valid on MULTI services
        if service.type != svc.MULTI:
            raise ValueError("a multi control group can only manage multi services (at %s)" % service.name)
        # Create the control unit for this group
        self.unit = MultiControlUnit(self)
        # Log the initialization event
        logging.info("%s: multi control group initialized" % service.name)


class MultiControlUnit(ControlUnit):
    def __init__(self, control_group):
        super(MultiControlUnit, self).__init__(control_group, control_group.service.name)
        # Initialize parameters
        self.last_partition = None
        self.zk = None
        self.services = []

    # noinspection PyUnusedLocal
    def param_job_handler(self, job_id, job_object_path, status, param):
        super(MultiControlUnit, self).job_event_handler(job_id, job_object_path, status)

    def prestart(self):
        # ZooKeeper instance
        self.zk = self.control_group.control_root.zk

        # List of service logics
        self.services = [ServiceLogic(self.zk, "%s@%s" % (self.name, s), self.control_group.service, self.get_unit(s),
                                      self.control_group.control_root)
                         for s in self.control_group.service.instances]

        # Register the resolver for prestart scripts
        def resolver(target_name):
            if self.last_partition is None:
                raise DelayPrestart()

            if target_name not in self.last_partition:
                raise UnknownInstance()

            if len(self.last_partition[target_name]) == 0:
                raise DelayPrestart()

            return ",".join(self.last_partition[target_name])

        for sl in self.services:
            self.control_group.control_root.register_resolver(sl.name, resolver)

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # ZooKeeper instance
        zk = self.zk

        # List of service logics
        services = self.services

        # List of services that are known to fail, and are included in the partitioning identifier
        known_failed_services = [service.name.split("@")[1] for service in services if service.is_failed()]

        with self.control_group.service.handler(self.param_job_handler):
            # Loop forever
            while not exit_event.is_set():
                # Create the partitioner
                partitioner_path = "/service_watcher/partition/%s" % self.control_group.service.name
                # Create the identifier
                identifier = "%s@%s" % (gethostname(), "@".join(known_failed_services))
                identifier_needs_update = False
                # Note that we use a set of tuples for the partitioner, but as we use a custom partition_func, so
                # this is ok
                partitioner = SetPartitioner(zk, partitioner_path, [[x[0], x[1]] for x in
                                                                    self.control_group.service.instances.items()],
                                             self.partition_func, identifier,
                                             self.control_group.control_root.timings['partitioner_boundary'],
                                             self.control_group.control_root.timings['partitioner_reaction'])
                logging.info("%s: created partitioner at %s" % (self.name, partitioner_path))

                try:
                    acquired = False

                    while not exit_event.is_set() and not partitioner.failed:
                        # update services
                        for service in services:
                            service.tick()

                            param = service.name.split("@")[1]
                            if service.is_failed() and param not in known_failed_services:
                                known_failed_services.append(param)
                                identifier_needs_update = True
                            elif not service.is_failed() and param in known_failed_services:
                                known_failed_services.remove(param)
                                identifier_needs_update = True

                        if identifier_needs_update:
                            break

                        if partitioner.release:
                            # immediately release set, we will perform a diff-update on the next acquire
                            logging.info("%s: releasing partitioner set" % self.name)
                            # service logics should take no action
                            for service in services:
                                service.set_should_run(None)
                            # actually release the partition
                            partitioner.release_set()
                        elif partitioner.acquired:
                            # we have a new set of services to run
                            new_p = [item.split("@")[0] for item in partitioner]

                            if not acquired:
                                logging.info("%s: acquired partition set" % self.name)
                                acquired = True

                            # update activation status
                            for service in services:
                                service.set_should_run(self.control_group.service.enabled and
                                                       service.name.split("@")[1] in new_p)

                            # run actions
                            for service in services:
                                service.actions()

                            # wait for wake-up, but not too long so we are still responsive to
                            # partitioner events
                            self.loop_tick(self.control_group.control_root.timings['loop_tick'])
                        elif partitioner.allocating:
                            acquired = False
                            logging.info("%s: acquiring partition" % self.name)
                            partitioner.wait_for_acquire()
                finally:
                    # Release the partitioner when leaving
                    partitioner.finish()

        # When exiting, stop all services
        for service in services:
            service.terminate(self.control_group.control_root.reload_exit)

    def partition_func(self, identifier, members, partitions):
        # Sort members so we have a consistent order over all allocators
        sorted_members = list(sorted(member.split("@")[0] for member in members))
        # Failed status of services for members
        failed_status = {}
        for member in members:
            split = member.split("@")
            failed_status[split[0]] = {}
            for q in split[1:]: failed_status[split[0]][q] = True
        # Sort partitions by service count then name
        sorted_partitions = list(sorted([[x[0], copy(x[1])] for x in partitions], key=lambda service: "%04d_%s" % (service[1], service[0])))
        # Original counts
        org_counts = [service[1] for service in sorted_partitions]

        logging.info("%s: from %s" % (self.name, json.dumps(partitions)))

        # Computed partition set: keys are values of members, values are arrays of assigned service ids (param@id)
        allocation_state = {}
        for m in sorted_members:
            allocation_state[m] = []

        # Computed service set: keys are instance names, values are worker arrays
        target_members = {}
        for param, count in sorted_partitions:
            target_members[param] = []

        # A reusable allocation method
        def try_allocate(i):
            param, count = sorted_partitions[i]
            id = org_counts[i] - count + 1

            target_host = None
            if param in self.control_group.service.force:
                target_host = self.control_group.service.force[param]
                if count > 1:
                    logging.warning("%s: ignoring force directive for service with more than one replica" % self.name)

            # Find the first member that can host the service with the least already-allocated services
            member_set = sorted(sorted_members, key=lambda member: \
                "%04d_%s" % (len(allocation_state[member]), member))
            for member_name in member_set:
                valid_host = param not in failed_status[member_name] and member_name not in target_members[param] \
                             and (not self.control_group.service.exclusive or len(allocation_state[member_name]) == 0)
                if target_host is None and valid_host or target_host == member_name:
                    # allocate service
                    allocation_state[member_name].append("%s@%d" % (param, id))
                    # mirror allocation state in target members
                    target_members[param].append(member_name)
                    # no instances left to allocate
                    sorted_partitions[i][1] -= 1
                    # yay
                    return True

            # No allocation
            return False

        # On the first pass, allocate only services with one required replica (probably master)
        for i in range(len(sorted_partitions)):
            if sorted_partitions[i][1] == 1:
                try_allocate(i)

        # Then each subsequent pass must allocate instances
        continue_allocating = True
        while continue_allocating:
            continue_allocating = False
            for i in range(len(sorted_partitions)):
                if sorted_partitions[i][1] > 0:
                    if try_allocate(i):
                        continue_allocating = True

        self.last_partition = target_members
        logging.info("%s: computed partition %s" % (self.name, json.dumps(allocation_state)))
        logging.info("%s: resolver state %s" % (self.name, json.dumps(target_members)))

        # The resulting "partition" is the set of services for the current instance
        return allocation_state[identifier.split("@")[0]]
