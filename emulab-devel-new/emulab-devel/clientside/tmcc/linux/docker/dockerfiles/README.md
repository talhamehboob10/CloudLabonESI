"Emulabizing" Docker Images
---------------------------

We do not want to force every Emulab user to build their environment
starting from one of our Docker images that has the Emulab clientside
plus a boatload of tools.  We want to allow users to bring existing
images into Emulab.  The overall README at [../README.md] explains this
further; this document simply explains how libvnode_docker.pm will use
the Dockerfile fragments and shell scripts in the subdirs of this dir to
take an existing Docker image, and Emulabize it to one level or
another.  This builds a new Emulabized image from their specified base
image, using the attributes they specified.

Our primary goal is to minimize the number of layers Emulabization adds,
and to stay docker image cache-compliant; secondary goals are ease of
use and maximum generalization/code reuse.  It is important that you
understand the caching and hierarchical limitations of the Dockerfile
RUN statement!  Go read that first:

  * https://docs.docker.com/engine/reference/builder
  * https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices

The main rule, though, is that whatever you put into a single RUN
statement should fully clean up any temporary files or side effects it
created.  That means if your RUN statement started with apt-get update,
you had better run apt-get clean all && rm -f /var/lib/apt/lists/* at
the end of that RUN statement!  Otherwise, all those apt/dpkg files will
remain in the layer... and if you remove them in a subsequent RUN
command, all you do is white them out -- you save no disk (layer) space.

We allow users to Emulabize modern Ubuntu, Debian, Fedora, and CentOS
images.  The [../container-utils/analyze.sh] script, in combination with
`docker inspect <image>`, tells us a bunch of stuff about the candidate
image (i.e., has it already been Emulabized to the desired level; what
distro/version it is; what init binary it has installed; if it already
has sshd installed; etc).

To create the new image from the candidate image, we create a
Dockerfile, OR use one, from the sources in this subdir corresponding to
the distro/version of the base image.

We allow the user to choose the level of emulabization, and to choose
their init binary (at runtime; note we always install runit to ensure we
have something that works everywhere, whether the vhost is a shared or
dedicated host).  They can choose the following levels:

#   none: we do not alter the image at all!
#   basic: install only openssh, rsyslog, and runit
#   core: basic + install a custom-build of the clientside, using a buildenv of
#     the image, but only installing the DESTDIR clientside binaries/fs stuff;
#     also install a whole bunch of packages the clientside stuff needs.
#   buildenv: basic + install all build tools for clientside, and
#     install the clientside, plus the runtime binaries the clientside needs.
#   full: buildenv + packages to make the image closer to a normal Emulab
#     disk image.

Then, if they've chose > none, at runtime, they can further choose
between 'installed' init, and the 'runit' init.  There is only one
caveat: if the installed init is systemd, we cannot support that on
SHARED vhost machines.  Thus we default to runit; it's lighter-weight too.

The Emulabization process looks for a subdir for the distro/version the
image is running.  That subdir must contain Dockerfile fragments for
each option (which are combined in order to form a generated Dockerfile,
with some boilerplate Docker goo, like FROM ...), AND shell scripts for
each option (that are automatically combined into a single, final RUN
... statement in the generated Dockerfile that follow all the
fragments).  We provide those options for maximum flexibility.  The
ability to provide an exact Dockerfile fragment for each option allows
any customization; whereas providing a shell script for each option
value allows arbitrary customization into a single RUN command (thus
limiting layer explosion).  The ideal way to write these file
combinations to minimize layers and maximizing caching utility is to
have Dockerfile fragments for each emulabization/init option that copy
necessary fragments from the context dir into the image fs; and then
scripts to manipulate the image fs as necessary.

For example, suppose we are emulabizing ubuntu:16.04.  Our process would
pull the image, boot it, and analyze it, to learn the distro/version and
other interesting metadata.  Then it would create the image CONTEXT dir
and start assembling a Dockerfile for image build.  The Dockerfile can
copy in any raw files in the CONTEXT dir; set Docker options; run
commands; etc.  We build this Dockerfile as follows.  The first line of
this Dockerfile is 'FROM <baseimage>'.  Based on the distro and version,
we find subdirs of this dir that apply to it.  In this case, we would
find common/, ubuntu, ubuntu16, and ubuntu-16-04 (if it existed, which
it does not).  In addition to copying these dirs into our CONTEXT dir
for this build, we add COPY statements into the generated Dockerfile
that copy them to /etc/emulab/CONTEXT/ in the build, so that the shell
scripts etc are available for use in a later RUN statement.  Each
applicable distro subdir may have an fs/ subdir in it; each of these
this gets rsync'd to the CONTEXT/ dir in order least-specific to most
specific.  Thus, in this case, ubuntu/fs comes first, then ubuntu16/fs.
We then add a COPY statement that COPYs anything in CONTEXT/fs/ to / in
the new image.

After this has finished, we try to generate a single master RUN
statement based on several kinds of files we look for, that correspond
to the desired Emulabization level (and one or more of the available
inits for this distro), to assemble the Dockerfile guts from.  The RUN
statement might be small if Dockerfile fragments have their own RUN
statements (although this whole process is geared to avoid that!); or it
might contain several shell scripts to run.  Suppose that we were
building a 'core' emulabized image.  We would look for several files in
each of the applicable distro/version subdirs: core.sh,
core-artifacts.sh, Dockerfile-core.  Shell scripts are combined into a
single omnibus RUN statement in the generated Dockerfile.  We also look
for a 'prepare.sh' and 'cleanup.sh' that are run at the beginning and
end of the generated RUN statement.  Any Dockerfile-X fragments we find
are just splatted into the Dockerfile.  The files in the most-specific
distro/version subdir are the winners; in this case, it's ubuntu16/.  We
further look for shell script and Dockerfile fragments for each of the
init binaries we support (runit, systemd, upstart).  Finally, we do this
script/fragment search for each Emulabization level the desired one
depends on.  These dependencies look like:

basic:    levels = basic
core:     levels = basic,core
buildenv: levels = basic,buildenv
full:     levels = basic,buildenv,full

One thing I haven't mentioned yet -- artifacts.  To Emulabize images
without leaving all the build tools inside them (to keep the new layer
size as low as possible!), each level can have an X-artifacts.sh
script.  If this script exists, the current distro subdir it is in will
be mounted read-only into a docker container using the base image.  Also
mounted will be an artifact output dir mounted rw, so that any built
binaries etc can be saved to the host.  The scripts are given a DESTDIR
env var that points to the rw artifact dir.  Whatever is placed into
this dir ends up in CONTEXT/artifacts.  Dockerfile fragments can COPY
stuff from the artifact dir into the new image we're building.
Obviously -- all X-artifacts.sh script are run prior to building the
real image, since they are inputs to the build.  Each artifact script
runs in its own container, but shares the rw artifact output dir will
all other artifact scripts for this build.  Scripts will be run in level
order, so if we're building a core image, basic-artifacts.sh would be
run prior to core-artifacts.sh .  Artifact scripts expect several
environment vars to be set:
   EMULABSRC -- points to the source tree, may be read-only
   PUBSUBSRC -- points to the pubsub source tree, may be read-only
   DESTDIR -- points to an empty read-write volume from the host

The RUN statement we end up for our new 'core' ubuntu 16.04 image looks
like this:

  /bin/sh -c 'cd /etc/emulab/CONTEXT && ubuntu/prepare.sh && cd /etc/emulab/CONTEXT && ubuntu16/basic.sh && cd /etc/emulab/CONTEXT && ubuntu16/core.sh && cd /etc/emulab/CONTEXT && ubuntu16/runit.sh && cd /etc/emulab/CONTEXT && ubuntu16/systemd.sh && cd /etc/emulab/CONTEXT && ubuntu/cleanup.sh && mkdir -p /etc/emulab && echo core > /etc/emulab/emulabization-type'

For later use at runtime, we look for Dockerfile fragments in a bit more
fine-grained way.  We look for Dockerargs-X (where X is runit, systemd,
upstart); these are extra arguments that are passed to 'docker create'
later on when the image is used.  We also look for Dockercmd-X (where X
is runit/systemd/upstart); these specify the startup command for the
image (if they don't exist, it will just be the detected initprog path
for whichever of runit/systemd/upstart the user chooses later during
runtime).  It is weird to decouple these bits from the image; some of
them actually could be specified in the image; BUT we don't want to
force a default startup command nor its arguments.  For instance,
`docker create` for a systemd-booted image requires lots more mount
points and special options than does a runit-booted image.  We don't
want to lock in any defaults.  We also don't want to take them as input
from the user, obviously, since containers launched on shared hosts must
be carefully restricted in behavior.

So, just to add a little more detail to what happens for ubuntu:16.04 core:

  * ubuntu/prepare.sh -- updates the apt package cache
  * ubuntu16/basic.sh -- installs runit, sshd, syslog
  * ubuntu16/core-artifacts.sh -- builds pubsub and Emulab clientside
    and installs to $DESTDIR/emulab-client-install (Dockerfile-core
    COPYs stuff from that dir into the new image /)
  * ubuntu16/core.sh -- installs a custom-built Emulab
      and pubsub binaries/clientside, that was built in
      core-artifacts.sh, and its binary package deps
  * ubuntu16/buildenv.sh -- installs the packages necessary for
      building and running the clientside, then builds and installs the
      clientside.
  * ubuntu16/full.sh -- installs a bunch of extra
      packages to make the image look like a traditional Emulab disk image
  * ubuntu16/runit.sh -- installs and configures runit
  * ubuntu16/systemd.sh -- configures the installed systemd
  * ubuntu16/Dockerargs-systemd: provides `docker create` CLI args necessary to
    boot a docker image with systemd
  * ubuntu16/Dockercmd-systemd: provides the command in the image that
      starts systemd 
  * ubuntu16/Dockercmd-runit: provides the command in the image that
      starts runit 
  * ubuntu/cleanup.sh -- cleans up the apt cache, /tmp, etc



