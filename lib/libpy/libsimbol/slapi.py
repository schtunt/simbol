class SLAPI:
    def __init__(self, datafile):
        self._oPF = ObjectPathFinder(datafile)

    def console(self):
        ipmiIpAddress = self._oPF['$.networkComponents[0].ipmiIpAddress']
        username = self._oPF['$.operatingSystem.passwords[0].username']
        password = self._oPF['$.operatingSystem.passwords[0].password']
        return 'ipmp://%s:%s@%s/' % (
            username, password, ipmiIpAddress
        )

    def hostinfo(self):
        datacenterName = self._oPF['$.datacenter.name']
        ipAddresses = self._oPF('$.networkComponents.*[@.name is "eth"].primaryIpAddress')
        return '%s@%s' % (','.join([_[1] for _ in ipAddresses]), datacenterName)
