Upgrading Emulab servers from FreeBSD 10.2 to 10.3.

These are fairly specific, but not always exact instructions for the process.
They are also oriented toward the CloudLab family of clusters, hence the
references to mothership, Clemson, Wisconsin, Apt, etc.

Start with the boss node, and then you will repeat the instructions for ops.
Note that there are a couple of steps below that you only do on the boss or
the ops node, so pay attention!

[XXX these would benefit from breaking ops out from boss as they are different
enough that describing them with a lather-rinse-repeat process is confusing...]

==========
BEFORE YOU START: Backup if you can!

If your boss and ops are VM on Xen, you can create shadows of the disks
that you can roll back to. Really only need to backup the root disk which
has all the FreeBSD stuff. Login to the control node and:

  # apt
  sudo lvcreate -s -L 33g -n boss.backup xen-vg/boss
  sudo lvcreate -s -L 33g -n ops.backup xen-vg/ops

  # cloudlab utah/clemson
  sudo lvcreate -s -L 17g -n boss.backup xen-vg/boss
  sudo lvcreate -s -L 17g -n ops.backup xen-vg/ops

This will seriously degrade the performance of the upgrade process due
to the inefficiencies of disk writes when shadows are present, but it is
worth it to avoid a total screw up.
==========

A. Updating the base FreeBSD system with freebsd-update

-1.Things you can do in advance.

   * The "fetch" part of freebsd-update (A2 and A4)
   * Build any custom kernel (A3)
   * Stash state about ports/packages (B0)

0. If you are on the boss node, shutdown the testbed and mysqld right off
   the bat. The ports upgrade is going to replace mysql and testbed daemons
   will wig out if running when this happens. On ops, you just need to
   shutdown mysqld:

   boss:

   sudo /usr/testbed/sbin/testbed-control shutdown
   sudo /usr/local/etc/rc.d/2.mysql-server.sh stop
   sudo /usr/local/etc/rc.d/capture stop

   ops:
   sudo /usr/local/etc/rc.d/1.mysql-server.sh stop
   
1. Before installing the new binaries/libraries/etc., you might want
   to back up the files that have Emulab changes just in case. Those files
   are:

     /etc/hosts
     /etc/ntp.conf       # if you have customized it
     /etc/ssh/sshd_config
     /etc/ttys           # if you have configured a serial console

   The easiest thing to do is just:

     sudo cp -rp /etc /Oetc

   NOTE: if you built and installed your system from sources originally,
   you may also get some conflicts with other files that record their origin
   in comments. Sendmail files are one example. Use the 10.3 versions of
   those to avoid future conflicts.

2. I generally don't want to update /usr/src (if it exists at all I keep
   it up to date with svn) or the kernel (if you have a custom kernel).
   So you will want to modify /etc/freebsd-update.conf and change the
   "Components" line to either:

   Components world kernel # don't update src

   or

   Components world # don't update src or kernel

3. (Optional) Upgrade your custom kernel
   If you have a custom kernel config, then you should build and install
   a new kernel first. Clone the FreeBSD 10.3 source repo:

   cd /usr
   sudo mv src Osrc
   sudo svn checkout -q svn://svn0.us-west.freebsd.org/base/releng/10.3 src
   <copy over your custom config file from Osrc/sys/amd64/conf/CUSTOM>

   # XXX you are supposed to "buildworld" before "buildkernel", but I don't
   cd src
   sudo make -j 8 buildkernel KERNCONF=CUSTOM

   # XXX I wait to install the custom kernel til after doing the
   # freebsd-update, since it will want to patch /boot/kernel files...
   #sudo make installkernel KERNCONF=CUSTOM

4. Now upgrade the base system:

     sudo freebsd-update -r 10.3-RELEASE upgrade

   or, if you want a real editor:

     sudo -E EDITOR=emacs freebsd-update -r 10.3-RELEASE upgrade

   It will crunch for a long time and then probably want you to merge
   some conflicts. Here are a couple to take note of:

     * /etc/ssh/sshd_config: make sure Protocol does not include 1,
       otherwise it will spit out constant warnings to the console.

     * /etc/ttys: for Xen VMs make sure the getty on ttyu0 is "off"
       and not "onifconsole". Otherwise you will have competing gettys
       on /dev/console.
   
   It will then show you a long, long list of files that it will be adding,
   deleting, etc. You can 'q' out of those.

5. Install the new system binaries/libraries/etc:

    sudo /usr/sbin/freebsd-update install

   After a while it will want you to reboot the new kernel. Before you reboot,
   install any custom kernel:

   cd /usr/src
   sudo make installkernel KERNCONF=CUSTOM

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

   NOTE: when rebooting boss, mysqlcheck might take awhile when rebooting.

   When it comes back up, you should login and shutdown services that
   restarted:

   boss:

   sudo /usr/local/etc/rc.d/2.mysql-server.sh stop
   sudo /usr/local/etc/rc.d/capture stop

   ops:
   sudo /usr/local/etc/rc.d/1.mysql-server.sh stop

   and then again run freebsd-update to finish:

    sudo /usr/sbin/freebsd-update install

   Now you can compare against the files you saved to make sure all the
   Emulab changes were propagated; e.g.:

     sudo diff -r /Oetc /etc

   Of course, this will show you every change made by the update as well,
   so you might just want to focus on the files above. When you are happy:

     sudo rm -rf /Oetc

6. The mothership may need some additional local hacks to some standard
   utilities, in particular "mountd" and "pw". Both should have a patch
   in the Emulab source tree patches subdir.

7. How did that work out for ya?

   If all went well, skip to B (Updating ports/packages).

   If that didn't work, see ~mike/upgrade-from-10.0.txt and follow steps
   A1 - A10. Return here for upgrading your ports.


B. Updating ports/packages

   Updating the core ports from 10.2 to 10.3 is pretty easy. However, if
   you installed extra ports that will require a bit more work.

0. Figure out the extra ports you have installed so that you can update
   them later. First make a list of everything installed:

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

   ====
   IMPORTANT NOTE: for those with Moonshot chassis, you cannot use an
   ipmitool port newer than 1.8.15 due to issues with "double bridged"
   requests. Either ipmitool or HPE got it wrong and it doesn't behave
   like ipmitool expects as of commit 6dec83ff on Sat Jul 25 13:15:41 2015.
   Anyway, you may want to "pkg lock" that package in this case as the
   FreeBSD 10.3 ports have a newer version.
   ====

   For ops, those commands are:

   pkg query "%n-%v %R" > ops.pkg.list
   grep -v 'Emulab$' ops.pkg.list | awk '{ print $1; }' > ops.pkg.local
   pkg query -x "%n %v usedby=%#r" `cat ops.pkg.local` | \
       grep 'usedby=0' | awk '{ print $1; }' > ops.pkg.reinstall


1. Modify your /etc/pkg/Emulab.conf file, replacing "10.2" with "10.3" in
   the "url" line:

      sudo sed -i .bak -e 's;/10.2/;/10.3/;' /etc/pkg/Emulab.conf

2. Unlock the pkg tool and install new packages:

    sudo pkg unlock pkg
    sudo -E ASSUME_ALWAYS_YES=true pkg upgrade -r Emulab

3. Fix perl/python paths.

   REALLY, REALLY IMPORTANT: the latest perl port does not install the
   /usr/bin/perl link which we use heavily in Emulab scripts. Ditto for
   python and the /usr/local/bin/python link. Make sure those two symlinks
   exist, e.g.:

      ls -la /usr/bin/perl /usr/local/bin/python

   If not, get them back with:

      ln -sf /usr/local/bin/perl5 /usr/bin/perl
      ln -sf /usr/local/bin/python2 /usr/local/bin/python

   REALLY, REALLY IMPORTANT PART 2: Because perl changed, you will need
   to make sure that the event library SWIG-generated perl module is rebuilt,
   and then all the event clients. Otherwise you will get bus errors when
   they all try to start. So do not skip step D2 below!

4. Upgrade mysql (see ~mike/upgrade-from-mysql55-to-mysql57 for details).

   First, make sure it isn't running:

      # boss
      sudo /usr/local/etc/rc.d/2.mysql-server.sh stop

      # on ops
      sudo /usr/local/etc/rc.d/1.mysql-server.sh stop

   You need to tweak some variables to keep mysqld memory usage down
   and fix up some directory permissions:

      cp /usr/local/etc/mysql/my.cnf /tmp/my.cnf
      cat <<EOF >>/tmp/my.cnf

# Added by Emulab
[mysqld]
innodb_buffer_pool_size         = 128M
innodb_data_file_path           = ibdata1:16M:autoextend
innodb_temp_data_file_path      = ibtmp1:48M:autoextend
performance_schema              = OFF
# End of Emulab added section
EOF
      sudo cp -p /usr/local/etc/mysql/my.cnf /usr/local/etc/mysql/my.cnf.bak
      sudo cp /tmp/my.cnf /usr/local/etc/mysql/my.cnf
      sudo chmod g+rwx \
          /var/db/mysql/ /var/db/mysql/mysql /var/db/mysql/performance_schema

   Ugh! ON BOSS ONLY we need to skip ahead here to updating your Emulab
   source tree so that we can install the new mysqld startup scripts.
   Note that we update both boss and ops scripts from the boss obj tree.
   You need to do D1 below to make sure your sources are up to date and then:

      cd <srcdir>
      git pull
      cd <objdir>/rc.d
      gmake
      sudo install -c -m 755 2.mysql-server.sh \
         /usr/local/etc/rc.d/2.mysql-server.sh
      sudo scp 1.mysql-server.sh ops:/usr/local/etc/rc.d/1.mysql-server.sh

   Whether updating boss or ops, restart mysql so you can do the upgrade
   and stop/start it yet again for the changes to take effect. Note that
   on ops, there is a different startup file and you have to give the DB
   password:

      # on boss
      sudo /usr/local/etc/rc.d/2.mysql-server.sh start
      sleep 2
      sudo mysql_upgrade
      sudo /usr/local/etc/rc.d/2.mysql-server.sh stop
      sleep 2
      sudo /usr/local/etc/rc.d/2.mysql-server.sh start

      # on ops
      # XXX note the "upgradestart" command!
      sudo /usr/local/etc/rc.d/1.mysql-server.sh upgradestart
      sleep 2
      sudo mysql_upgrade -p`cat /usr/testbed/etc/mysqld.pwd`
      sudo /usr/local/etc/rc.d/1.mysql-server.sh stop
      sleep 2
      sudo /usr/local/etc/rc.d/1.mysql-server.sh start

   It is possible that on the ops node you will have an old password.
   If you do:

      mysql -u root -p`sudo cat /usr/testbed/etc/mysqld.pwd` mysql

   and it complains about an invalid user, then you will need to:
     
      sudo /usr/local/etc/rc.d/1.mysql-server.sh stop
      sleep 2
      sudo /usr/local/etc/rc.d/1.mysql-server.sh upgradestart
      sleep 2
      # XXX fix up the password info
      set foo=`sudo cat /usr/testbed/etc/mysqld.pwd`
      echo \
        "UPDATE user SET authentication_string=password('$foo') WHERE User='root';" \
        | mysql mysql
      sudo /usr/local/etc/rc.d/1.mysql-server.sh stop
      sleep 2
      sudo /usr/local/etc/rc.d/1.mysql-server.sh start


5. Reinstall local ports.

   To find ports that are installed but that are not part of the Emulab
   repository:
   
   pkg query "%t %n-%v %R" `cat boss.pkg.reinstall` |\
       grep -v Emulab | sort -n

   These will be sorted by install time. You can see ones that are old
   and attempt to reinstall them with "pkg install". Note that just because
   they are old that doesn't mean they need to be reinstalled.

C. Repeat steps A and B for ops.

D. Update Emulab software

1. Make sure your Emulab sources are up to date.

   You must use the emulab-devel repository at this point as only it has
   the necessary changes to support FreeBSD 10.3. If you don't already
   have an emulab-devel repo, clone it with:

   git clone git://git-public.flux.utah.edu/emulab-devel.git
     or
   git clone http://git-public.flux.utah.edu/git/emulab-devel.git

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
      sudo gmake all boss-install 

   The reason for the ops install is that, while boss-install updates
   most of the ops binaries/libraries via NFS, there are some that it
   doesn't. So by doing a separate build/install on ops, you are
   guaranteed to catch everything.

   If the boss install tells you that there are updates to install,
   run the command like it says:

      sudo gmake update-testbed
      
   This will actually turn the testbed back on at the end so you will
   not have to do #3 below. Note also that this command may take awhile
   and provide no feedback.

3. Re-enable Emulab services and make sure nothing obvious blows up:

   sudo /usr/testbed/sbin/testbed-control boot

4. Reboot boss and ops again!

   NOTE: if you reboot ops after boss, you may need to restart all the
   event schedulers from boss:

   sudo /usr/testbed/sbin/eventsys_start

E. Update the MFSes

   This is not strictly part of updating the OS, but it would be good to
   do this if you have not for awhile. See the instructions in
   ops.emulab.net:~mike/upgrade-mfs.txt.
