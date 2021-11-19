This is a detailed discussion and list of design decisions made during
the addition of Docker as a supported Emulab vnode type.

Overview
--------
Emulab client-side Docker vnode support relies on the libvnode
mechanism.  Thus, the vast majority of the code is in libvnode_docker.pm .

In Emulab, vnodes are launched on vhost boot, rc.bootsetup runs
bootvnodes which runs a vnodesetup process for each vnode.  On Linux,
for Emulab vnode types that are built using the libvnode abstraction,
vnodesetup calls mkvnode.pl, which invokes all the libvnode library
calls to build, boot, shutdown, and destroy the vnode, as necessary
during its lifecycle.  mkvnode.pl acts as a monitor.  See further detail
in the "Container Lifecycle" section below.


Container Lifecycle
-------------------

What happens when user types reboot or shutdown?  Those don't tend to
work in Docker containers :).  We're not going to force them to work in
this first version; it would require some inside/outside collaboration.
The main helpful thing we can do is allow the user to interact with
Docker CLI tools in the normal way (at least on dedicated vhosts) --
i.e., to type `docker restart pcvmXXX-Y`, and have all the Emulab stuff
that was setup in mkvnode.pl and libvnode_docker.pm continue to work.
This is harder than it seems, since Docker provides no access to the
default container runtime's (runc) hook support!  What a bad decision;
it causes us tremendous pain.

The way vnodes are launched in Emulab has traditionally been that on
vhost boot, rc.bootsetup runs bootvnodes which runs a vnodesetup process
for each vnode.  On Linux, for Emulab vnode types that are built using
the libvnode abstraction, vnodesetup calls mkvnode.pl, which invokes all
the libvnode library calls to build, boot, shutdown, and destroy the
vnode, as necessary during its lifecycle.

Typically, mkvnode.pl acts as a "monitor"/watchdog process.  Emulab
control software will signal it with USR1/2 to tell it to shutdown or
restart; any other signal to mkvnode.pl (like INT) will result in the
vnode being halted and destroyed.  Usually, the expectation of
mkvnode.pl is that if the vnode dies unilaterally (i.e. is not signaled
nor rebooted), mkvnode.pl should die as well (i.e. the
libvnode::vnodeState call that is invoked by mkvnode.pl every ~5seconds
will eventually return VNODE_HALTED() or whatever, and mkvnode.pl will
return.

However, to support the Docker libvnode backend, we instead introduced
libvnode::vnodePoll(), which (if it exists) mkvnode.pl will call in a
loop until it is told specifically to stop polling.  The Docker
implementation of libvnode::vnodePoll() subscribes to the JSON event
stream for the container, and is thus able to catch events like
uncommanded container death; docker-CLI-commanded restart or stop; and
it continues to run forever, never returning to mkvnode.pl unless there
is an error.  This is necessary for Emulab (libvnode_docker.pm) to hook
the shutdown and startup of a container, so we can do extra
configuration of it.  When we see a "die", we undo our boot hooks.
When we see a "restart", we redo our boot hooks.

In the second version of this, we will further inform this event-based,
asynchronous mechanism with an inside-outside collaboration.  If the
initscripts inside see that this container is being launched by Emulab,
they will wait until the container has been "hooked" before proceeding
to boot; and work similarly on shutdown.

We also ensure that neither dockerd nor the vhost distro autostart
containers on boot; we want to start them, so we can re-create all the
associated goo, like network devices and tc qdiscs etc; and monitor
their execution via the docker event stream.  We could relax this later
by adding a central daemon that listens for all container events, and
invokes mkvnode.pl for the corresponding operation, if it's not already
running.  Needs more thought; mkvnode.pl assume it is in charge right now.


Container Boot
--------------

For now, we do not attempt to emulate the built-in image entrypoint or
command; we simply override them (on the belief that most uses will
choose generic Linux distro images whose default command is usually
/bin/bash or similar).

[TODO] Later, we will support command emulation, so that images that
really want to launch only httpd or whatever will still work.


Deployment/Orchestration
------------------------
We don't support 'docker compose' or the multi-host overlays, etc.  We
are the orchestrator!  If user wants to do a docker compose or swarm or
whatever, they can do that on the vnode host; they just better not use
our control net.  They would have to intend to do that; the default
docker bridge is a private network.


Emulabization
-------------
We do support booting unmodified, external Docker images from the main
registry in containers.  There are several drawbacks to this, however.
Emulab cannot manage their lifecycle nor enable any features for these
containers, other than what can be done from the outside (i.e., network,
traffic shaping, firewalling, NFS mounts); other features must be done
from the inside (event sys, program agents, linktest, user
accounts/keys, startup commands).  Well, startup commands we *could* do
from the outside, but what's the point?  The image already has a builtin
command, or the user would provide one.  They already don't want to use
our mechanisms for content deployment; they just want to use our
container and network deployment mechanism.

(See also the "Init Strategy" discussion; it is part of the motivation
for Emulabizing images.)

So -- we also support (and hope that people will primarily use)
automatic Emulabization.  The user can bring their own image (based on
Ubuntu, Centos (and later Fedora and Debian)), and we will automatically
Emulabize it to the level they choose  We support several different
levels:

    none: we do not alter the image at all!
    basic: install only openssh, rsyslog, runit, and several runit initscripts
    core: basic + install a custom-build of the clientside, using a
      temporary buildenv of the image, but only installing the DESTDIR
      clientside binaries/fs stuff; also install a bunch of packages the
      clientside stuff needs.
    buildenv: basic + install all build tools for clientside, and
      install the clientside, plus the runtime binaries the clientside needs.
    full: buildenv + packages to make the image closer to a normal Emulab
      disk image.

This gives the user maximum flexibility -- do they want a small image
that's not messed with at all (or is miminally messed with, as in the
basic case); or do they want something more and more featureful that
supports the core set of Emulab features.  Size matters, right?  We
invest significant time to ensure that whatever we do add is added in as
few layers as possbile.

[TODO] If the image doesn't have sshd and we're not Emulabizing, then
fire up an sshd on the per-vnode port that simply allows remote users to
attach to the console or to exec a shell inside the container.  It is
actually very complicated to have non-local users login via ssh and run
a command.  Too bad... some very basic version of that would work great
here!

[TODO] If we're not emulabizing, and if the image does have sshd, and if
there is a USER specified in the base image, mount an authorized_keys
files from the outside.  Or maybe we won't do this; it doesn't seem
likely to happen in practice.


Init Strategy
-------------
Fact: the original Docker model is that each container is just a
process, or collection of processes, like Apache MPM.  In this model,
you don't want to encumber the container with a full-blown init that can
reap zombies and run other services.  However, this is a fairly narrow
use case, when you get down to it.  Many services depend on syslog,
cron, or remote access via ssh.  Certainly *experimentation* as a
service depends on them!  99.99% of the time, Emulab experimenters are
not going to run the standard docker perl image whose entrypoint is
/usr/bin/perl, and runs some one-shot perl thing.

Clearly, few real uses of Docker inside Emulab will use containers in
this mode.  In an Emulab experiment, you typically want the ability to
login to your containers, see logs, and run other services.  Plus you're
running academic software, and that might leave a fair number of zombies
lying around.  Then, if you want the advanced features of the clientside
(like events, users, keys), you need init's service support.  Finally,
most Linux distro base containers' entrypoint/cmd setup is /bin/sh or
some variant.

So we need an init, to run and supervise services; reap zombies; and be
the one process that runs to keep the vnode up.  Most modern distros now
have systemd installed as the default init.  Unfortunately it doesn't
work in fully unprivileged docker as of April 2017.  The main hangup is
that systemd requires /sys/fs/cgroup to boot, and the cgroup filesystem
didn't obtain namespace support until kernel 4.4 (we cannot allow a
shared docker host until we can hide the root cgroup fs from the
containers, because that exposes things about the other experiments on
the machine).  Docker (runc) doesn't utilize this support yet; maybe
something is still pending in the kernel featureset.  See also

  https://www.freedesktop.org/wiki/Software/systemd/ContainerInterface/
  https://www.cyphar.com/blog/post/rootless-containers-with-runc
  https://developers.redhat.com/blog/2016/09/13/running-systemd-in-a-non-privileged-container/
  https://hub.docker.com/r/solita/ubuntu-systemd/
  https://github.com/solita/docker-systemd/blob/master/Dockerfile

There are other problems with systemd/docker, like the inability to run
a getty on the console; see

  https://docs.docker.com/engine/reference/run/#foreground
  https://github.com/docker/docker/issues/27202
  https://github.com/systemd/systemd/pull/4262

That one seems to be legitimately Docker's fault, but it seems to have
fallen off the radar.

Finally, upstart isn't going to have a path to long-term use, although
it's still present in Ubuntu 14, of course... so we have to support it
for Ubuntu 14.

To sum up: we allow users to choose the "installed" init on dedicated VM
hosts, if they really really want to use systemd/upstart; the reason to
do this is that most people write initscripts for
systemd/upstart/sysvinit at this point, so if they want to "just run"
openvswitch for instance, it will "just work" via the distro's stock
init path.  However, we always also install runit for the most basic of
Emulabization.  runit is also our default init, if the user does not
elect to use the installed init on dedicated vnodes.  We considered
defaulting to the installed init on dedicated vnodes, but that would
lead to a very inconsistent shared vs dedicated experience for users.
We do our best with our simple runit initscripts to ensure that systemd
will not execute them via its runit.service, if it is in control, and
will instead run them natively.

(There is no point whatsoever to writing a simple init ourselves.
Docker already provides a basic command-wrapper fully-static-linked init
that reaps zombies; that's all that's needed for that use case.
Obviously, we cannot write an init in sh, since the Bourne shell can't
wait() on *any* child (only its jobs).  ise I would have done so.  We
could write a simple init in Python and assume that most containers have
Python, but even that won't always be true.  Too much bother, and
nonstandard to boot.  So forget all that.)


Network
-------
There are many shortcomings and a few legit bugs in docker's libnetwork
implementation.  We've worked around all of them; but some actually need
patching to provide all the Docker functionality at the same time as our
functionality.

When we boot up the vhost for the first time, we create a _dockercnet
network that corresponds to and provides access to the Emulab control
network.  This is not the default Docker network.  If that exists, we
move it (by changing the /etc/docker/daemon.json config file) to a
private 192.168.254.0/24 subnet.  We support both macvlan or bridging
for the control net; either Docker builds macvlan virtual control net
devs atop the real control net dev; or we put the real dev into a
bridge, along with Docker-created virtual devs.  Note that docker
creates the virtual devs and puts them in the bridge or creates them
atop the parent macvlan device; we don't do that; we can't even hook it.
We default the control net to bridging so that we can use iptables rules
on the bridged virtual devices.  It's not clear that we can use the same
method for control net iptables with macvlans; see
libvnode_docker::InsertPostBootIptablesRules().

Each experiment network is modeled by a Docker network.  We support
either macvlans or bridging for experiment, just like for the control
net.  By default we use bridging.  Currently experiment networks are
broken for the shared vhost case, since Docker networks *must* all have
a vhost-unique subnet.  In other words, networks are l2/l3, and can
speak to each other over l3.  There is no concept of an l2-only network;
they have been open to that, but no one ever wrote a patch.  I guess
we'll be the ones to do it.

Docker assumes it is in control of /etc/hosts and /etc/resolv.conf .
So, we use its /etc/hosts mechanism to add all the hostname/ip mappings
we would normally generate inside the vnode in rc.hostnames; and we
mount /etc/resolv.conf read-only from the host into the container.
Otherwise, it does nasty stuff with /etc/resolv.conf (like running a
resolver on 127.0.0.11, and not letting us overwrite that for our kind
of networks -- which seems to contradict the docs).  Anyway, the
read-only mountover works... ugh!

We do all traffic shaping outside the vnodes.  That means the same
methods work for both dedicated and shared vhosts; but that link agents
don't work.  That seems to be acceptable right now; AFAIK this is the
same strategy libvnode_xen takes.  If I recall correctly, we also have
to use bridging for experiment networks, so that we can route traffic
through ifb devices for ingress shaping.  I think that trick doesn't
work with macvlan devices, although I could be remembering incorrectly.
Anyway, we default to bridging for experiment networks for now.

Docker assumes it is in control of iptables; we'll have to hack a couple
simple features into place to avoid this.  First, each time it operates
on a container, it forces a jump to its DOCKER-ISOLATION chain as the
first rule in the FORWARD chain.  This makes it very hard for us to do
any custom firewalling.  Second, it assumes control of the POSTROUTING
chain in the NAT table.  We don't always want to MASQ all traffic
leaving an Emulab container; sometimes the private, unroutable control
net is routable locally within the cluster, and we don't want that
traffic MASQ'd.  However, Docker doesn't let us stay in control of the
order of rules in this chain.  So in the first iteration of this, we
simply disable Docker's iptables support (it's on or off), and do our
own thing.  We still MASQ external container traffic on its default
bridge; but not for any other user-defined networks.  This is
unfortunate; we'll have to patch Docker to fix this.

We carefully orchestrate the control and multiple experiment networks so
that the control net gateway becomes the default gateway.  Docker
doesn't make this easier; if you don't create a default gateway for each
network, it will create one for you!  Moreover, since Emulab doesn't
assign a gateway (why should it, after all) for each virtual network, we
have to assume the top address in the experiment network subnet is
free... and we use that as the Docker subnet gateway.  Of course, this
address isn't ever used... but if the Emulab user uses a full subnet,
there will be a conflict.  This will require a patch, too.  [TODO]

A bug: virtual dev mac addrs are set incorrectly inside the container,
for experiment network devices.  This contradicts the docs and is
probably a bug to fix.  This unfortunately renders rc.ifconfig useless,
since it can't find the ifaces it thinks are there; but since all that
configuration is applied by Docker, it doesn't matter.

Something left to do still: since control net is wide open to virt
control net, we really need to add anti-spoofing rules on the outbound
bridge, like we do for openstack (except have to do it with linux bridge
or macvlan).  By wide open, I mean it is trivial for people to get a
dynamic address from Docker in our virt control net.  They just have to
make a mistake!  Or we could also figure out how to deal more
restrictively with the IPAM driver for our Emulab control and experiment
networks.  It would be ideal if there was a no-dynamic address mode!
However, this would mean writing our own IPAM driver; we cannot affect
the behavior of any of the built-in drivers.


Security
--------
By default, all containers are unprivileged.  This is also the only mode
for containers on shared hosts.  However, since each container has its
own network namespace, we do add CAP_NET_BIND_SERVICE, CAP_NET_RAW, and
CAP_NET_ADMIN to all vnodes.

[TODO] Users on dedicated hosts can request privileged containers.

Each vnode has its own mount namespace, so it would sort of be nice if
users could mount things inside their containers.  Sadly, this would
require CAP_SYS_ADMIN, so we cannot enable this on shared vhosts.
Moreover, it is further impossible on shared vhosts since cgroups are
only somewhat namespaced, and docker (via runc) doesn't yet provide each
container with its own cgroup namespace.


LVM and Docker Storage Backends
-------------------------------
We support infrastructure LVM via USE_LVM; for now it is always set.
Our VG is "docker".

For Docker storage, we support both the default aufs driver and the
devicemapper (with thin provisioning) driver.  We use LVM in both cases,
and in both cases we place /var/lib/docker into one of our LVs, and
symlink it back.

In the aufs case, we only create two LVs; one (/vminfo) to host minor
stuff from /var/emulab/vms; and another (/vms) to host all kinds of
stuff, including /var/lib/docker, and our image building context dir.
/vms is approximately 90% of the docker VG; /vminfo is 5GB or 3%VG.

In the devicemapper/thin-provisioned case, /vminfo is the same; /vms
still hosts /var/lib/docker and context build dirs -- but hosts no
container FS data.  So we create a thinpool (in our VG) for that, and
tell Docker to use it.  /vminfo is min(5GB,3%VG); /vms is
min(32GB,15%remainingVG); thinpool is 90%remainingVG.


Mountpoints and Block Storage
-----------------------------

Because containers on shared hosts are unprivileged (and because
dedicated vhost containers are also by default unprivileged), we must do
all mounts from the vhost.  We support NFS mounts already; but not block
storage.

[TODO] To support a block storage mount on a shared vhost, we would have
to mount the block store in a separate, privileged service vnode, and
then mount that dir into the non-privileged vnode.  Very painful.  This
also means that the raw block device isn't available for fs formatting
or whatnot.  We may need to revisit this; i.e. if a dedicated docker
container is mounting a remote block store device, then automatically
privilege it and allow it to create and modify the raw device.


Bugs
----
/proc/sys/net is unwriteable (despite the fact that it's a separate netns!)
  https://github.com/docker/docker/issues/21649

MAC addresses for secondary networks are not set as per documentation.

