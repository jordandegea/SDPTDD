import tempfile
import re
import os
import yaml

instance_regex = re.compile("\\{instance:([a-z@_]+)\\}")


class PrestartScript(object):
    def __init__(self, script):
        super(PrestartScript, self).__init__()
        self.script = script
        self.last_exec_state = None

    def save_state(self, path):
        with open(path, "w") as f:
            yaml.dump(self.last_exec_state, f)

    def load_state(self, path):
        if os.path.isfile(path):
            with open(path, "r") as f:
                self.last_exec_state = yaml.load(f)
        else:
            self.last_exec_state = None

    def get_script_contents(self, resolver_func):
        # Invoke the resolver on all instance:xxx variables
        exec_state = {}

        def cb(match):
            key = match.group(1)
            val = resolver_func(key)
            exec_state[key] = val
            return val

        result = instance_regex.sub(cb, self.script)
        self.last_exec_state = exec_state
        return result

    def is_dirty(self, resolver_func):
        if self.last_exec_state is None:
            return True

        for k in self.last_exec_state:
            try:
                if self.last_exec_state[k] != resolver_func(k):
                    return True
            except DelayPrestart:
                return True

        return False

    def will_delay(self, resolver_func):
        for k in self.last_exec_state:
            try:
                resolver_func(k)
            except DelayPrestart:
                return True

        return False

    def execute(self, resolver_func):
        with tempfile.NamedTemporaryFile(delete=False) as tmp:
            try:
                tmp.write(self.get_script_contents(resolver_func))
                tmp.close()
                os.chmod(tmp.name, 0o750)
                os.system(tmp.name)
            except DelayPrestart:
                raise RetryExecute()
            finally:
                os.unlink(tmp.name)


class RetryExecute(Exception):
    """ Exception thrown when resolving an instance for a prestart template failed and execution should be retried
    later """
    pass


class DelayPrestart(Exception):
    """ Exception thrown by a resolver to indicate no instance is available yet and execution should be delayed """
    pass


class UnknownInstance(Exception):
    """ Exception thrown by a resolver to indicate no such instance could be ever resolved """
    def __init__(self, instance_name):
        super(UnknownInstance, self).__init__()
        self.instance_name = instance_name

    def __str__(self):
        return "Unknown instance %s" % self.instance_name


class ResolvingNotSupported(Exception):
    """ Exception thrown by a resolver to indicate this kind of unit cannot be resolved """
    pass
