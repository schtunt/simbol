#!/usr/bin/env python
import libsimbol

import os, sys, getpass
import paramiko, base64
import binascii, socket, errno
import futures
from select import select
from sha import sha
from threading import Thread, Lock

from time import sleep
from random import random

from libsimbol.secret import vault

import signal
g_interrupted = False
def signal_handler(signum, frame):
    global g_interrupted
    g_interrupted = True
signal.signal(signal.SIGINT, signal_handler)

import logging
ll = logging.FATAL
logging.basicConfig(level=ll)
#logging.getLogger("paramiko").setLevel(ll)

#class MHKP(paramiko.MissingHostKeyPolicy):
class MHKP(paramiko.AutoAddPolicy):
    def __init__(self, *argv, **kwargs):
        paramiko.AutoAddPolicy.__init__(self, *argv, **kwargs)

    def missing_host_key(self, client, hostname, key):
        client._host_keys.add(hostname, key.get_name(), key)
        #if client._host_keys_filename is not None:
        #    client.save_host_keys(client._host_keys_filename)
        return None

class EssEssHache:
    _known_hosts = os.path.expanduser('~/.ssh/known_hosts')

    def __init__(self, threads, timeout):
        self._clients = {}
        self._threads = threads
        self._timeout = timeout

    def add_clients(self, qdns):
        for qdn in qdns:
            client = paramiko.SSHClient()
            client.load_host_keys(self._known_hosts)
            client.set_missing_host_key_policy(MHKP())
            self._clients[qdn] = client

    def del_client(self, qdn):
        client = self._clients.pop(qdn)
        if client._host_keys_filename is not None:
            client.save_host_keys(client._host_keys_filename)
        client.close()

    def connect(self, username, qdn, command, stdin=[]):
        #sleep(2 * random())

        client = self._clients[qdn]
        client.known_hosts = None
        data = None
        try:
            data = (qdn, [], [], 1)
            try:
                ssh_proxy_host = os.environ.get('SSH_PROXY_HOST', None)
                ssh_proxy_port = os.environ.get('SSH_PROXY_PORT', '22')
                tld = os.environ.get('TLD', None)
                #sys.stdout.write("%s=%s\n" % ('ssh_proxy_host', ssh_proxy_host))
                #sys.stdout.write("%s=%s\n" % ('tld', tld))

                if not ssh_proxy_host:
                    client.connect(qdn, username=username, timeout=self._timeout)
                else:
                    #sys.stderr.write("#. >>> Queued up %s via proxy %s\n" % (qdn, ssh_proxy_host))
                    proxy_command = paramiko.ProxyCommand(
                        "ssh -p %s %s@%s nc %s.%s 22" % (
                            ssh_proxy_port, username, ssh_proxy_host, qdn, tld
                        )
                    )
                    client.connect(qdn, username=username, sock=proxy_command, timeout=self._timeout)

                stdout = []
                stderr = []
                ecode = -1

                if stdin:
                    chan = client.get_transport().open_session()
                    _stdin = chan.makefile('wb')
                    _stdout = chan.makefile('rb')
                    _stderr = chan.makefile_stderr('rb')

                    #. If stdout is still open then sudo is asking us for a password
                    if True not in [_stdin.channel.closed, _stdout.channel.closed]:
                        chan.exec_command(command)

                        for line in stdin:
                            _stdin.write("%s\n" % line)
                        _stdin.flush()

                        ecode = chan.recv_exit_status()
                        stdout = _stdout.readlines()
                        stderr = _stderr.readlines()
                    else:
                        estr = "StdinClosedButData"
                        stderr = [estr]
                        stdout = []
                        ecode = 4
                else:
                    _stdin, _stdout, _stderr = client.exec_command(command)
                    ecode = _stdout.channel.recv_exit_status()
                    stdout = _stdout.readlines()
                    stderr = _stderr.readlines()

                data = (qdn, stdout, stderr, ecode)

            except paramiko.BadHostKeyException as exception:
                estr = "Bad Host Key"
                data = (qdn, [], [estr], 2)

            except paramiko.SSHException as exception:
                estr = "Unknown Host"
                data = (qdn, [], ["%s: %s" % (estr, str(exception))], 2)

            except socket.timeout as exception:
                estr = "TCP Socket Timeout"
                data = (qdn, [], [estr], 3)

            except socket.error as exception:
                if exception.errno == errno.EHOSTUNREACH:
                    estr = "Host Unreacheable"
                    data = (qdn, [], [estr], 4)
                elif exception.errno == errno.ETIMEDOUT:
                    estr = "Timeout"
                    data = (qdn, [], [estr], 4)
                elif exception.errno == errno.ECONNRESET:
                    estr = "Connection Reset"
                    data = (qdn, [], [estr], 4)
                else:
                    estr = "C %s: %s (%s)" % (exception.__class__, exception, exception.errno)
                    data = (qdn, [], [estr], 7)

            except Exception as exception:
                estr = "B %s: %s" % (exception.__class__, exception)
                data = (qdn, [], [estr], 8)

            else:
                self.del_client(qdn)

        except Exception as exception:
            estr = "A %s: %s" % (exception.__class__, exception)
            data = (qdn, [], [estr], 9)

        return data


    def writeMeABASHScript(self, var, username, password, cmd):
        mutex = Lock()

        sys.stdout.write("#!/bin/bash\n")
        sys.stdout.write("#. threads: %d\n" % self._threads)
        sys.stdout.write("#. timeout: %0.1f\n" % self._timeout)
        sys.stdout.write("\n")
        with futures.ThreadPoolExecutor(max_workers=self._threads) as executor:
            #. See if stdin from the shell has any data to offer...
            #stdindata = []
            #if select([sys.stdin,],[],[],0.0)[0]:
            #    stdindata = [_.strip('\n') for _ in sys.stdin.readlines()]

            stdindata = []
            if password:
                cmd = """sudo -S %s""" % cmd
                stdindata.append(password)

            queue = {
                executor.submit(self.connect, username, qdn, cmd, stdindata):
                    qdn for qdn in self._clients.keys()
            }

            sys.stdout.write("local -A %s\n"   % var) #. stdout
            sys.stdout.write("local -A %s_o\n" % var) #. stdout
            sys.stdout.write("local -A %s_e\n" % var) #. stderr
            sys.stdout.write("local -A %s_w\n" % var) #. warnings

            i = 0
            total = len(self._clients.keys())

            #for future in futures.as_completed(queue, timeout=self._timeout):
            for future in futures.as_completed(queue):
                i += 1

                qdn = queue[future]
                data = None
                try:
                    #data = future.result(timeout=self._timeout)
                    data = future.result()
                except futures.TimeoutError:
                    sys.stdout.write("#. %s is taking too long. Oh well.\n" % qdn)
                else:
                    mutex.acquire()
                    try:
                        sys.stdout.write("#. %s -={\n" % qdn)

                        _qdn, stdout, stderr, e = data
                        qdn_hash = sha(qdn).hexdigest()
                        sys.stdout.write(
                            "#. Query with host %s (%d of %d) : %s\n" % (
                                qdn, i, total, future._state
                            )
                        )

                        sys.stdout.write("%s[%s]=%d\n" % (var, qdn_hash, e))

                        if len(stdout) > 0:
                            sys.stdout.write("read -r -d '' %s_o[%s] <<-!\n" % (var, qdn_hash))
                            sys.stdout.write(''.join(stdout).strip())
                            sys.stdout.write("\n!\n")

                        if len(stderr) > 0:
                            sys.stdout.write("read -r -d '' %s_e[%s] <<-!\n" % (var, qdn_hash))
                            sys.stdout.write(''.join(stderr).strip())
                            sys.stdout.write("\n!\n")

                        sys.stdout.write("#. }=- %s\n\n" % qdn)
                    finally:
                        mutex.release()

            sys.stdout.write("#. All done.\n")

def main():
    '''
    Assumptions:

        1. You have ssh public keys in place to connect to remote hosts
        2. If you supply a sudo secret id, you want to wrap the command in sudo
    '''
    e=1

    usage = """
Usage: ssh <threads> <timeout> <var>=<username>[:<sudo-secret-id>]@<host>,<host>,<host>,... <cmd>
"""

    if len(sys.argv) >= 3:
        threads = int(sys.argv[1])
        timeout = float(sys.argv[2])

        var = None
        username = None
        qdns = list()
        cmd = None

        var, remainder = sys.argv[3].split('=', 1)
        password = None
        username, remainder = remainder.split('@', 1)
        if ':' in username:
            username, sid = username.split(':', 1)
            password = secret(sid)

        qdns = remainder.split(',')
        cmd = ' '.join(sys.argv[4:])

        ssh = EssEssHache(threads, timeout)
        ssh.add_clients(qdns)

        ssh.writeMeABASHScript(var, username, password, cmd)

        e=0
    else:
        print(usage)

    return e

if __name__ == '__main__':
    e = 1
    try:
        e = main()
    except KeyboardInterrupt:
        e = 130
    except (IOError, OSError):
        e = 141

    sys.exit(e)
