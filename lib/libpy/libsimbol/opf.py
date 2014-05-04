import sys, json
from pyobjpath.core.interpreter import Tree

class ObjectPathFinder:
    def __init__(self, datafile):
        self._datafile = datafile
        with open(datafile) as fH:
            self._tree = Tree(json.load(fH))

    def __call__(self, path, tree=None):
        processed = []

        tree = tree or self._tree.execute(path)
        t = type(tree)

        if t is list:
            for key, subtree in enumerate(tree):
                processed.extend(self('%s[%d]' % (path, key), subtree))
        elif t is dict:
            for key, subtree in tree.items():
                processed.extend(self('%s.%s' % (path, key), subtree))
        else:
            processed.append((path, tree))

        return processed

    def __getitem__(self, path):
        pydata = self(path)
        return pydata[0][1]

    def dump(self, path='$.*'):
        for k, v in self(path):
            sys.stdout.write('%s=%s\n' % (k, v))
