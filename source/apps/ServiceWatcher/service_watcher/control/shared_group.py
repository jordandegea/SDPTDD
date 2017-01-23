import logging
import json
from copy import copy
from socket import gethostname

from kazoo.recipe.partitioner import SetPartitioner

from service_watcher import service as svc
from service_watcher.control.base_group import ControlGroup, ControlUnit
from service_watcher.control.utils import ServiceLogic

from service_watcher.prestart import *


class SharedControlGroup(ControlGroup):
    def __init__(self, control_root, service):
        super(SharedControlGroup, self).__init__(control_root, service)
        # Only valid on shared services
        if self.service.type != svc.SHARED:
            raise ValueError("a shared control group can only manage shared services (at %s)" % service.name)
        # Create the control unit for this group
        self.unit = SharedControlUnit(self)
        # Log the initialization event
        logging.info("%s: shared control group initialized" % service.name)


class SharedControlUnit(ControlUnit):
    def __init__(self, control_group):
        # Initialize underlying thread
        # Note that the thread name is unique also in the ZooKeeper znode space
        super(SharedControlUnit, self).__init__(control_group, control_group.service.name)
        # Initialize attributes
        self.last_partition = None
        self.zk = None
        self.sl = None

    def prestart(self):
        # ZooKeeper instance
        self.zk = self.control_group.control_root.zk

        # Encapsulated logic for the managed shared service
        self.sl = ServiceLogic(self.zk, self.control_group.service.name, self.control_group.service, self.get_unit(),
                               self.control_group.control_root)

        # Register the resolver for prestart scripts
        def resolver(target_name):
            if target_name != self.control_group.service.name:
                raise UnknownInstance(target_name)

            if self.last_partition is None or len(self.last_partition) == 0:
                raise DelayPrestart()
            return ",".join(self.last_partition)

        self.control_group.control_root.register_resolver(self.sl.name, resolver)

    def run(self):
        # Event to signal the thread should exit
        exit_event = self.control_group.control_root.exit_event

        # Get the reference to sl and zk
        zk = self.zk
        sl = self.sl

        # Current status
        enabled = False

        with self.control_group.service.handler(self.job_event_handler):
            # Loop forever
            while not exit_event.is_set():
                # The shared service for this unit is currently failed, so stay out of the partition waiting for the
                # unit to be reset
                sl.tick()

                if sl.is_failed():
                    self.loop_tick(self.control_group.control_root.timings['failed_loop_tick'])
                else:
                    # Create the partitioner
                    partitioner_path = "/service_watcher/partition/%s" % self.control_group.service.name
                    # Note that we use the service as a set for the partitioner, but as we use a custom partition_func,
                    # so this is ok
                    partitioner = SetPartitioner(zk, partitioner_path, self.control_group.service,
                                                 self.partition_func,
                                                 "%s:%s" % (gethostname(), "true" if enabled else "false"),
                                                 self.control_group.control_root.timings['partitioner_boundary'],
                                                 self.control_group.control_root.timings['partitioner_reaction'])
                    logging.info("%s: created partitioner at %s" % (self.name, partitioner_path))

                    try:
                        acquired = False

                        while not exit_event.is_set() and not partitioner.failed and not sl.is_failed():
                            # update service status from systemd
                            sl.tick()

                            if sl.should_run is not None:
                                if sl.should_run != enabled:
                                    enabled = sl.should_run
                                    break

                            if partitioner.release:
                                # immediately release set, we will perform a diff-update on the next acquire
                                logging.info("%s: releasing partitioner set" % self.name)
                                # note that we should now leave the service as-is, while waiting for what to do
                                sl.set_should_run(None)
                                # actually release the partition
                                partitioner.release_set()
                            elif partitioner.acquired:
                                # we have a new partition
                                new_p = list(partitioner)

                                if not acquired:
                                    logging.info("%s: acquired partition set" % self.name)
                                    acquired = True

                                # the service should run if the partition is non-empty
                                sl.set_should_run(self.control_group.service.enabled and len(new_p) > 0)

                                # force taking actions
                                sl.actions()

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
                        # No action should be taken
                        sl.set_should_run(None)
                        # Remove scheduled state
                        sl.tick()

        # When exiting, stop all services
        sl.terminate(self.control_group.control_root.reload_exit)

    def partition_func(self, identifier, members, service):
        # Sort members so we have a consistent order over all allocators
        sorted_members = list(sorted(member[:member.index(":")] for member in members))

        # Print initial state
        logging.info("%s: from %s" % (self.name, json.dumps(list(members))))

        # Parse current allocated state
        allocated_status = {}
        for member in members:
            split = member.split(":")
            allocated_status[split[0]] = (split[1] == "true")

        # Allocation state for members
        allocation_state = {}
        # Member allocation status
        target_members = []
        # Initialize state
        for member in sorted_members:
            allocation_state[member] = []

        # Reusable allocation method
        def allocate(member, count):
            allocation_state[member].append(str(service.count - count + 1))
            target_members.append(member)
            allocated_status[member] = True

        # Apply current allocation state
        count = copy(service.count)
        for member in allocated_status:
            if allocated_status[member] and count > 0:
                allocate(member, count)
                count -= 1
            else:
                allocated_status[member] = False

        # Allocate left instances
        for member in sorted_members:
            if count > 0 and not allocated_status[member]:
                allocate(member, count)
                count -= 1

        self.last_partition = target_members
        logging.info("%s: computed partition %s" % (self.name, json.dumps(allocation_state)))
        logging.info("%s: resolver state %s" % (self.name, json.dumps(target_members)))

        # The resulting "partition" is the set of services for the current instance
        return allocation_state[identifier[:identifier.index(":")]]
