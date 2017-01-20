import logging
import json
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
                                service.set_should_run(service.name.split("@")[1] in new_p)

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
        sorted_members = list(sorted(members))
        sorted_partitions = list(sorted(partitions, key=lambda x: x[0]))
        allocation_state = {}
        allocation_params = {}
        allocated = {}
        target_members = {}

        for param, count in sorted_partitions:
            target_members["%s@%s" % (self.control_group.service.name, param)] = []

        for member in sorted_members:
            allocation_params[member] = {}
            allocation_state[member] = []
            allocated[member] = False

        allocations = []
        for part in sorted_partitions:
            if part[1] == 1:
                allocations.append("%s@1" % part[0])
                part[1] = 0

        services_left = True
        while services_left:
            services_left = False
            for service in sorted_partitions:
                if service[1] > 0:
                    allocations.append("%s@%d" % (service[0], service[1]))
                    service[1] -= 1
                    services_left = True

        current_member = 0
        for instance in allocations:
            param = instance.split("@")[0]

            if param in self.control_group.service.force:
                target_host = self.control_group.service.force[param]

                # Forced allocation strategy
                for member_spec in sorted_members:
                    member_splitted = member_spec.split("@")
                    if target_host == member_splitted[0]:
                        allocated[member_spec] = True
                        allocation_state[member_spec].append(instance)
                        allocation_params[member_spec][param] = True
                        target_members["%s@%s" % (self.control_group.service.name, param)].append(member_splitted[0])
                        break
            else:
                # Default allocation strategy
                next_current_member = current_member
                for i in range(len(sorted_members)):
                    member_spec = sorted_members[(current_member + i) % len(sorted_members)]
                    member_splitted = member_spec.split("@")
                    member_failed = member_splitted[1:]

                    if param not in member_failed:
                        # If running in exclusive mode for this service, do not allocate
                        # a service to a worker that already has another service from
                        # this pool allocated
                        if (not self.control_group.service.exclusive or not allocated[member_spec]) and \
                                param not in allocation_params[member_spec]:
                            allocated[member_spec] = True
                            allocation_state[member_spec].append(instance)
                            allocation_params[member_spec][param] = True
                            target_members["%s@%s" % (self.control_group.service.name, param)].append(
                                member_splitted[0])
                            next_current_member += 1
                            break
                current_member = next_current_member

        self.last_partition = target_members
        logging.info("%s: computed partition %s" % (self.name, json.dumps(allocation_state)))
        logging.info("%s: resolver state %s" % (self.name, json.dumps(target_members)))

        # The resulting "partition" is the set of services for the current instance
        return allocation_state[identifier]
