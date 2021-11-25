Upgrading Emulab servers from FreeBSD 11.3 to 12.2.

These are fairly specific, but not always exact instructions for the process.
They are also oriented toward the CloudLab family of clusters, hence the
references to mothership, Clemson, Wisconsin, Apt, etc.

The most significant changes are:
 * python2.7 has been replaced by python 3.x
 * swig3 has been replaced by swig4

Start with the boss node, and then you will repeat the instructions for ops.
Note that there are a couple of steps below that you only do on the boss or
the ops node, so pay attention!

A. Things to do in advance of shutting down Emulab.

   These first few steps can be done in advance of shutting down your site.
   These include making a backup, fetching the new release files and merging
   in local changes, building a custom kernel (if you use one), and stashing
   away state about your current packages.

1. BACKUP IF YOU CAN!

   If your boss and ops are VM on Xen, you can create shadows of the disks
   that you can roll back to. Really only need to backup the root disk which
   has all the FreeBSD stuff. Login to the control node and:

   # for thinly provisioned VMs
   sudo lvcreate -s -n boss.backup xen-vg/boss
   sudo lvcreate -s -n ops.backup xen-vg/ops
   
   # apt/cloudlab utah/clemson
   sudo lvcreate -s -L 17g -n boss.backup xen-vg/boss
   sudo lvcreate -s -L 17g -n ops.backup xen-vg/ops

   # wisconsin
   sudo lvcreate -s -L 40g -n boss.backup xen-vg/boss
   sudo lvcreate -s -L 40g -n ops.backup xen-vg/ops

   For regular LVM volumes, this will seriously degrade the performance of the
   upgrade process due to the inefficiencies of disk writes when shadows are
   present, but it is worth it to avoid a total screw up.

   For thinly-provisioned snapshots of thin volumes, snapshots should not
   affect the performance of the upgrade significantly.

1b. Make sure you have sufficient disk space!

   I have never run out of disk space during the process below, but if
   you did, I suspect it could be a mess to recover. If you have at least
   4GB free on the root filesystem, you should be fine. Otherwise, you
   might need to make some space.

2. Fetch the new release with freebsd-update.

   This will not install anything, it will just fetch the new files and merge
   local changes in. You can do this on both boss and ops simultaneously.

   Do not do it too far (i.e., more than a day) in advance, since the base
   system changes and your local mods may change as well. For example, new
   users might be added in the interim which would invalidate your merged
   changes. 

   Before fetching, make sure your /etc/freebsd-update.conf is correct,
   in particular the "Components" line.

   By default it will want to update your kernel ("kernel") and source tree
   ("src") as well as the binaries ("world"). Life will be much easier if you
   go with the flow and just let it do that. The only reason we had for using
   a non-GENERIC kernel was related to running in a VM with more that 4 "sda"
   (emulated SCSI) devices. There, the standard FreeBSD NCR driver was causing
   problems. The other reason might be if you had to add some non-standard
   driver.

   If you have a custom source tree (or update it yourself with svn or git)
   then remove "src" from the line:

     Components world kernel # don't update src

   If you have a custom kernel, then remove "kernel":

     Components world # don't update src or kernel

   However, because you are changing major releases, rebuilding your
   custom kernel (next step) will require rebuilding the entire world first,
   which takes a long time and pretty much elimiates the advantages of
   using the binary update system. So, you might reconsider why you have a
   custom kernel and move back to the default kernel instead. If you opt
   for the default GENERIC kernel, make sure to leave "kernel" in the
   components above.

   Once you have /etc/freebsd-update.conf squared away, do the "fetch"
   part of the upgrade:

     sudo freebsd-update -r 12.2-RELEASE upgrade

   Since this will ask you to merge a bunch of local changes into various
   files and will want to fire up an editor, you might want to make sure
   you get a *real* editor by doing:

     sudo -E EDITOR=emacs freebsd-update -r 12.2-RELEASE upgrade

   instead. Otherwise you will probably wind up with vi. If you forget,
   you can always temporarily (or permanently!) replace /usr/bin/vi with
   /usr/local/bin/emacs when it first prompts you to manually handle
   a merge.

   It will crunch for a long time and then probably want you to merge
   some conflicts. Many will just be the FreeBSD header, but some other
   possible diffs:

     /etc/hosts.allow. We customized this to block rpcbind, tftpd, and
     bootinfo access from outside the local network.

     /etc/ntp.conf. We may have replaced the version string with our own
     header. For the merge you should leave both. We leave out all the
     default restrict/server/etc. lines in favor of our own. Do leave in
     the "leapfile" info.

     /etc/syslog.conf. They finally got rid of "ppp" and its exclusion
     may cause some diffs. Take that out of our version and leave in all
     the "Added by Emulab" changes. All of our stuff should be before the
     "!*" and includes of directories.

     /etc/inetd.conf (ops). We have a "flashpolicy" line at the end that
     conflicts with their "prom-sysctl" somehow. Just remove our line and
     leave theirs.

     /etc/ssh/ssh_config (ops). We have a couple of "Host *" options.
     Keep those and use the new version string.

   NOTE: if you built and installed your system from sources originally,
   you may also get some conflicts with other files where it calls out diffs
   is the RCS header or in comments. Favor the newer versions of those to
   hopefully avoid future conflicts.

     REALLY IMPORTANT NOTE: if it shows you a diff and asks you if something
     "looks reasonable" and you answer "no", it will dump you out of the
     update entirely and you have to start over. It will *not* just let you
     fire up the editor and fix things!

   After handling the diffs, it will then show you several potentially long
   lists of files that it will be adding, deleting, etc. It uses "more" to
   display them, so you can 'q' out of those without dumping out of the
   update entirely (the last one will exit the update, but that is because
   it is done).

   DO NOT do the install as it suggested at the end. We will get there
   in step B3 below. There are some other things that might need doing first.

3. (Optional) Upgrade your custom kernel.

   If you have a custom kernel config, then you should build and install
   a new kernel first. As mentioned in the last step, this will take a long
   time because you must build (but not install) the entire world before
   building the kernel. You can again do this on boss and ops simultaneously.

   Clone the FreeBSD 12.2 source repo:

   cd /usr
   sudo mv src Osrc
   sudo svn checkout -q svn://svn0.us-west.freebsd.org/base/releng/12.2 src
   <copy over your custom config file from Osrc/sys/amd64/conf/CUSTOM>

   cd src
   sudo make -j 8 buildworld
   sudo make -j 8 buildkernel KERNCONF=CUSTOM

4. Stash away the current set of packages you have installed.

   This will allow you to figure out the extra ports you have installed so
   that you can update them later. First make a list of everything installed:
   Do this on boss and then on ops. For boss:

   mkdir ~/upgrade
   cd ~/upgrade
   pkg query "%n-%v %R" > boss.pkg.list

   This is mostly to keep track of any ports you may have installed locally.
   One way to determine local installs is to see which ports did NOT come
   from the Emulab repository:

   grep -v 'Emulab$' boss.pkg.list | awk '{ print $1; }' > boss.pkg.local

   This will give you the list of packages that you may need to reinstall.

   You may want to list the dependencies of each to see what the top-level
   packages are and just install those.

   pkg query -x "%n %v usedby=%#r" `cat boss.pkg.local` | \
       grep 'usedby=0' | awk '{ print $1; }' > boss.pkg.reinstall

   Now login to ops and do the same thing:

   cd ~/upgrade
   pkg query "%n-%v %R" > ops.pkg.list
   grep -v 'Emulab$' ops.pkg.list | awk '{ print $1; }' > ops.pkg.local
   pkg query -x "%n %v usedby=%#r" `cat ops.pkg.local` | \
       grep 'usedby=0' | awk '{ print $1; }' > ops.pkg.reinstall

B. Updating the base FreeBSD system

1. (CloudLab clusters only) Shut the cluster down at the portal.

   Maybe 10-15 minutes before you plan on starting the upgrade, take
   the cluster offline at the CloudLab portal to allow things to settle:

     # On mothership boss
     wap manage_aggregate chflag -a <clustername> disabled yes

   Cluster name comes from running "wap manage_aggregate list" on
   the Mothership boss. Use the "Nickname".
   
2. If you are on the boss node, shutdown the testbed and some other services
   right off the bat.

   boss:
     sudo /usr/testbed/sbin/testbed-control shutdown
     sudo /usr/local/etc/rc.d/apache24 stop
     # NOTE capture may not be installed
     sudo /usr/local/etc/rc.d/capture stop

   ops:
     sudo /usr/local/etc/rc.d/1.mysql-server.sh stop
     sudo /usr/local/etc/rc.d/apache24 stop
     # NOTE capture may not be installed
     sudo /usr/local/etc/rc.d/capture stop
   
3. Before installing the new binaries/libraries/etc., you might want to back
   up the files that have Emulab changes just in case. Those files are:

     /etc/hosts
     /etc/ntp.conf       # if you have customized it
     /etc/ssh/sshd_config
     /etc/ttys           # if you have configured a serial console

   The easiest thing to do is just:

     sudo rm -rf /Oetc
     sudo cp -rp /etc /Oetc

4. Install the new system binaries/libraries/etc:

   If it has been more than a day or so since you did the "upgrade"
   command back in step A2, then you might consider doing it again because
   new users and group might have been added. Doing it again basically
   throws away everything it built up on the previous run and you will
   have to go through all the manual merging again. Or you can try the
   WORKAROUND below.

   Once you are satisfied, do the install of the new binaries:

    sudo /usr/sbin/freebsd-update install

  After a while it will want you to reboot the new kernel. Before you reboot,
  if you built a custom kernel back in step A3, install it now:

   cd /usr/src
   sudo make installkernel KERNCONF=CUSTOM

   When I did the custom kernel install, I saw errors of the form:

      kldxref /boot/kernel
      kldxref: unknown metadata record 4 in file atacard.ko
      kldxref: unknown metadata record 4 in file atp.ko
      ...

   They did not seem to affect the following boot.

   NOTE: I have noticed a couple of times on VM-based elabinelab boss/ops
   upgrades that the root filesystem has some issues after the upgrade,
   so it is good to run an fsck. I prefer to do this while shutting down.
   Before you do this, make sure you first have access to the console!

   sudo shutdown now

   umount -at nfs
   umount -at ufs
   accton	# turn off accounting that has a file open on /
   mount -o ro -u /
   fsck -y /
   reboot

   NOTE: when rebooting boss, mysqlcheck might take awhile (5-10 minutes).
   During this time, it won't say much...^T is your friend. The ops reboot
   will also take awhile for the ZFS mounts, but it will talk to you while
   it is doing it.

   When it comes back up, you should login and shutdown services that
   restarted, including some that won't work right.

   boss:
     sudo /usr/testbed/sbin/testbed-control shutdown
     sudo /usr/local/etc/rc.d/apache24 stop
     sudo /usr/local/etc/rc.d/2.dhcpd.sh stop
     sudo /usr/local/etc/rc.d/2.mysql-server.sh stop
     # NOTE capture may not be installed
     sudo /usr/local/etc/rc.d/capture stop

   ops:
     sudo /usr/local/etc/rc.d/apache24 stop

   and then again run freebsd-update to finish:

    sudo /usr/sbin/freebsd-update install

   NOTE that it will tell you to rebuild all third-party packages and
   run freebsd-update again. We do this later below, so don't worry.

   WORKAROUND: if you want to ensure that no new users/groups have been
   added to the system since you did the "freebsd-update fetch", then
   you can compare the files you stashed off in /Oetc to the ones that
   have now been updated in /etc:

     sudo diff /Oetc/passwd /etc/passwd
     sudo diff /Oetc/group /etc/group

   If there are differences, other than new FreeBSD users (ntp, tests),
   you will need to manually merge the new accounts from /Oetc to /etc.

   LATE BREAKING NEWS: we have noticed that the changes to the password
   file (adding user _ypldap and changing "games" homedir) don't seem
   to be reflected due to the .db files not get properly recreated.
   (If "echo ~games" shows "/usr/games" instead of "/"). Remake the DB
   files to be certain:

     sudo pwd_mkdb -p /etc/master.passwd

   If you don't get this sorted out now, it may cause problems when you
   add users to the testbed later. In particular, when adding user "foo"
   it might spit out messages:

     pw: user 'foo' disappeared during update

   In general, if you are paranoid you can now compare against the files
   you saved to make sure all the Emulab changes were propagated; e.g.:

     sudo diff -r /Oetc /etc

   Of course, this will show you every change made by the update as well,
   so you might just want to focus on the files listed in B2 above.

   Watch our for files that have appeared and disappeared as well:

     sudo diff -r /Oetc /etc | grep '^Only'

   If you are happy you can removed /Oetc, but I would keep it around
   for a few days/weeks in case something comes up.

   RANDOM: to avoid complaints from syslog about "unknown priority name"
   you need to create a missing directory:

     sudo mkdir -p /usr/local/etc/syslog.d

5. (Utah only) Apply Emulab patches to select system utilities.

   We have patched a couple of system utilities to better handle the
   large number of users, groups and filesystem mounts that the Emulab
   Mothership and assorted CloudLab clusters sport. Other sites really
   don't need to (and probably should not) do this.

   Make sure you have the appropriate FreeBSD source tree installed.

   Make sure you have the Emulab source tree checked out:

     cd ~
     git checkout https://gitlab.flux.utah.edu/emulab/emulab-devel.git testbed

   Since you probably don't have any of the FreeBSD "tests" infrastructure
   installed, you need to prevent it from attempting to install stuff there.
   Edit /etc/src.conf and add the line:

     WITHOUT_TESTS=yes

   Now patch, build, and install the Emulab versions:

     # on boss you just need the "pw" patch
     cd /usr/src/usr.sbin/pw
     sudo patch -p1 < ~/testbed/patches/FreeBSD-12.2-pw-2.patch
     sudo make obj
     sudo make all install clean

     # on ops you should install all patches
     cd /usr/src/usr.sbin/pw
     sudo patch -p1 < ~/testbed/patches/FreeBSD-12.2-pw-2.patch
     sudo make obj
     sudo make all install clean
     # mountd patch is no longer needed, yea!
     cd /usr/src/sbin/mount
     sudo patch -p1 < ~/testbed/patches/FreeBSD-12.2-mount.patch
     sudo make obj
     sudo make all install clean

6. How did that work out for ya?

   If all went well, skip to C (Updating ports/packages).

   If that didn't work, contact testbed-ops.

C. Updating ports/packages

   Updating the core ports from 11.3 to 12.2 is pretty easy if you were
   running the most recent set of 11.3 packages. Note that if you installed
   extra ports, upgrading will require a bit more work.

   You also need to ensure that Apache is not running (see A3 above)
   as PHP will be getting upgraded.

0. If you forgot to save off your package info back in A4, or it has been
   awhile, then you might want to go back and do that now.

   You may also want to back up config files for third-party packages:

      sudo cp -rp /usr/local/etc /usr/local/Oetc

1. Modify your /etc/pkg/Emulab.conf file, replacing "11.3" with "12.2" in
   the "url" line:

      sudo sed -i .bak -e 's;/11.3/;/12.2/;' /etc/pkg/Emulab.conf

2. Update the pkg tool and install new packages:

   Since you changed major versions it will prompt you to run
   "pkg bootstrap". That won't work with the Emulab package repository,
   so instead just reinstall pkg:

    sudo pkg update
    sudo pkg install -f -r Emulab pkg
    sudo -E ASSUME_ALWAYS_YES=true pkg upgrade -r Emulab

3. Tweak package installs:

   REALLY, REALLY IMPORTANT: at some point, the perl port stopped installing
   the /usr/bin/perl link which we use heavily in Emulab scripts. Ditto for
   python and the /usr/local/bin/python link. Since the version of python
   also changed, just be safe and remake the symlinks:

      sudo ln -sfn /usr/local/bin/perl /usr/bin/perl
      sudo ln -sfn /usr/local/bin/python3.7 /usr/local/bin/python
      # verify
      ls -laL /usr/bin/perl /usr/local/bin/python

   REALLY, REALLY IMPORTANT PART 2: Because perl changed, you will need
   to make sure that the event library SWIG-generated perl module is rebuilt,
   and then all the event clients. Otherwise you will get bus errors when
   they all try to start. So do not skip step E2 below!

   REALLY, REALLY IMPORTANT PART 3: For those with Moonshot chassis,
   you cannot use an ipmitool port *newer* than 1.8.15 due to issues with
   "double bridged" requests. Either ipmitool or HPE got it wrong and it
   doesn't behave like ipmitool expects as of commit 6dec83ff on
   Sat Jul 25 13:15:41 2015. Anyway, you will need to relace the standard
   ipmitool install with the "emulab-ipmitool-old-1.8.15_1" package from
   the emulab repository, unless you already had it installed. Do:

     pkg info | grep ipmi

   and if it shows the "-old" version is installed, you are okay. Otherwise:

     sudo pkg unlock ipmitool
     sudo pkg delete ipmitool
     sudo pkg install -r Emulab emulab-ipmitool-old
     sudo pkg lock ipmitool

   But ONLY do this if you have Moonshot chassis.

3b. (OPTIONAL) Additional package cleanup.

   To make sure your packages are in a consistent state you should remove
   some lingering packages:

     # look carefully at what it wants to do!
     sudo pkg autoremove
     # check everything
     sudo pkg check -adB
   
4. Changes from python2.7 to python 3.7?

   [ We will probably need to rebuild the event system stubs, but that
     is not an install-time thing. ]

5. Reinstall local ports.

   To find ports that are installed but that are not part of the Emulab
   repository:
   
   cd ~/upgrade
   pkg query "%t %n-%v %R" `cat boss.pkg.reinstall` |\
       grep -v Emulab | sort -n

   These will be sorted by install time. You can see ones that are old
   and attempt to reinstall them with "pkg install". Note that just because
   they are old that doesn't mean they need to be reinstalled.

   This is a point at which you might want to check for security problems:

     sudo pkg audit -F

   It is possible that some packages will have vulnerabilities, so unless
   it sounds really serious, just live with it.

6. Update your /etc/make.conf file in the event that you need to build a
   port from source in the future. Make sure your DEFAULT_VERSION line(s)
   look like:

  DEFAULT_VERSIONS=perl5=5.32 python=3.7 php=7.4 mysql=5.7 apache=2.4 tcltk=8.6
  DEFAULT_VERSIONS+=ssl=base

D. Repeat steps B and C for ops.

E. Update Emulab software

1. Make sure your Emulab sources are up to date.

   You must use the emulab-devel repository at this point as only it has
   the necessary changes to support FreeBSD 12.2. If you don't already
   have an emulab-devel repo, clone it with:

   git clone https://gitlab.flux.utah.edu/emulab/emulab-devel.git

   Make sure to copy over your existing defs-* file to the new source
   tree.

2. Reconfigure, rebuild, and reinstall the software.

   You want everything to be built against the new ports and libraries
   anyway though, so just rebuild and install everything.

   In your build tree, look at config.log to see how it was configured
   and then:

      # on both (in different build trees!)
      cd <builddir>
      head config.log	# see what the configure line is
      sudo rm -rf *
      <run the configure line>

      # on ops -- do this first
      sudo gmake opsfs-install

      # on boss -- do this after ops
      sudo /usr/local/etc/rc.d/2.mysql-server.sh start
      # install any DB updates
      sudo gmake update-testbed-noinstall
      # install everything
      sudo gmake all boss-install 

      # boss random: this file may be leftover from an elabinelab origin;
      # it should not be here (it SHOULD exist on ops)
      sudo rm /usr/local/etc/rc.d/ctrlnode.sh

   The reason for the ops install is that, while boss-install updates
   most of the ops binaries/libraries via NFS, there are some that it
   doesn't. So by doing a separate build/install on ops, you are
   guaranteed to catch everything.

3. Re-enable the testbed on boss.

   # NOTE capture may not be installed
   sudo /usr/local/etc/rc.d/capture start
   sudo /usr/local/etc/rc.d/apache24 start
   sudo /usr/local/etc/rc.d/2.dhcpd.sh start
   sudo /usr/testbed/sbin/testbed-control boot

4. Re-run the freebsd-update again to remove old shared libraries.

   Now that everything has been rebuilt:

   sudo freebsd-update install

5. Reboot boss and ops again!

   NOTE: if you reboot ops after boss, you may need to restart all the
   event schedulers from boss:

   sudo /usr/testbed/sbin/eventsys_start

6. (CloudLab clusters only) Reenable the cluster at the portal.

     # On mothership boss
     wap manage_aggregate chflag -a <clustername> disabled no

   Cluster name comes from running "wap manage_aggregate list" on
   the Mothership boss. Use the "Nickname".

F. Update the MFSes

   This is not strictly part of updating the OS, but it would be good to
   do this if you have not for awhile. See the instructions in
   ops.emulab.net:~mike/upgrade-mfs.txt.
