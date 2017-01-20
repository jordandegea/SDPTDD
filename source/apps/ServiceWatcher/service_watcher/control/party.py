import re

from socket import gethostname
from kazoo.recipe.party import ShallowParty

def fast_id():
    t = gethostname()
    return t[0] + "-" + re.search(r'\d+$', t).group()

class SWParty(ShallowParty):
    def __init__(self, client, path, **kwargs):
        super(SWParty, self).__init__(client, path, fast_id())
        self.joined = False
        self.on_join = None
        self.on_leave = None

        if "joined" in kwargs:
            self.on_join = kwargs["joined"]
        if "left" in kwargs:
            self.on_leave = kwargs["left"]

    def join(self):
        if not self.joined:
            super(SWParty, self).join()
            self.joined = True
            self.invoke_handler(self.on_join)
            return True
        return False

    def leave(self):
        if self.joined:
            super(SWParty, self).leave()
            self.joined = False
            self.invoke_handler(self.on_leave)
            return True
        return False

    def invoke_handler(self, handler):
        if handler is not None:
            handler(self)
