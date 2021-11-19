#!/usr/bin/env python

#
# This is a simple python script that attaches to a Docker container,
# and exports its stdout/err and stdin as a pty.
#
# We have this little python gem because it isn't possible to easily
# override the perl LWP::Protocol::SocketUnixAlt thing to steal its
# socket.  The standard python docker API wrapper, OTOH, gives it to us
# straightaway.
#

import os
import fcntl
import sys
import traceback
import pty
import docker
import select
import signal

if docker.version_info[0] < 2:
    import docker.client
    client = docker.client.AutoVersionClient()
    socket = client.attach_socket(
        resource_id=sys.argv[1],
        params=dict(stdout=True,stderr=True,stdin=True,stream=True,logs=True))
else:
    client = docker.from_env()
    container = client.containers.get(sys.argv[1])
    socket = container.attach_socket(
        params=dict(stdout=True,stderr=True,stdin=True,stream=True,logs=True))
sockfd = socket.fileno()
flags = fcntl.fcntl(sockfd,fcntl.F_GETFL)
fcntl.fcntl(sockfd,fcntl.F_SETFL,flags | os.O_NONBLOCK)
(mfd,sfd) = pty.openpty()
print os.ttyname(sfd)
if len(sys.argv) > 2:
    os.symlink(os.ttyname(sfd),sys.argv[2])
flags = fcntl.fcntl(mfd,fcntl.F_GETFL)
fcntl.fcntl(mfd,fcntl.F_SETFL,flags | os.O_NONBLOCK)

retval = 0

def cleanup(signum,frame):
    global retval

    if signum:
        sys.stderr.write("Caught signal %s, exiting!\n" % (str(signum),))
    if signum in [signal.SIGPIPE,signal.SIGALRM,signal.SIGABRT]:
        retval = -signum
    try:
        os.close(mfd)
        os.close(sfd)
        socket.close()
    except:
        pass
    if len(sys.argv) > 2:
        try:
            os.unlink(sys.argv[2])
        except:
            pass
    sys.exit(retval)

signal.signal(signal.SIGINT,cleanup)
signal.signal(signal.SIGALRM,cleanup)
signal.signal(signal.SIGPIPE,cleanup)
signal.signal(signal.SIGHUP,cleanup)
signal.signal(signal.SIGABRT,cleanup)
signal.signal(signal.SIGTERM,cleanup)
signal.signal(signal.SIGUSR1,signal.SIG_IGN)
signal.signal(signal.SIGUSR2,signal.SIG_IGN)

try:
    (sockbuf,mbuf) = ('','')
    while True:
        iwlist = []
        if len(sockbuf):
            iwlist.append(mfd)
        if len(mbuf):
            iwlist.append(sockfd)
        (rlist,wlist,xlist) = select.select([sockfd,mfd],iwlist,[],None)
        if sockfd in rlist:
            l = len(sockbuf)
            sockbuf += socket.recv(4096)
            if (len(sockbuf[l:])) == 0:
                sys.stderr.write("container went away, exiting\n")
                cleanup(None,None)
            sys.stderr.write("reads: %d\n" % (len(sockbuf[l:])))
        if mfd in rlist:
            l = len(mbuf)
            mbuf += os.read(mfd,4096)
            sys.stderr.write("readm: %d\n" % (len(mbuf[l:])))
        if len(mbuf) and sockfd in wlist:
            n = socket.send(mbuf)
            sys.stderr.write("sents: %d\n" % (len(mbuf[:n])))
            if n < len(mbuf):
                mbuf = mbuf[n:]
            else:
                mbuf = ''
        if len(sockbuf) and mfd in wlist:
            n = os.write(mfd,sockbuf)
            sys.stderr.write("sentm: %d\n" % (len(mbuf[:n])))
            if n < len(sockbuf):
                sockbuf = sockbuf[n:]
            else:
                sockbuf = ''
except:
    traceback.print_exc()
    retval = -1

cleanup(None,None)
