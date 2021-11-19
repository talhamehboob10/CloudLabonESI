How to upgrade from 10.0 to 10.2.

BEFORE YOU START: Backup if you can!

If your boss and ops are VM on Xen, you can create shadows of the disks
that you can roll back to. Login to the control node and:

  # cloudlab utah
  sudo lvcreate -s -L 17g -n boss.backup xen-vg/boss
  sudo lvcreate -s -L 250g -n boss.disk1.backup xen-vg/boss.disk1
  sudo lvcreate -s -L 250g -n boss.disk2.backup xen-vg/boss.disk2
  sudo lvcreate -s -L 100g -n boss.disk3.backup xen-vg/boss.disk3
  sudo lvcreate -s -L 17g -n ops.backup xen-vg/ops
  sudo lvcreate -s -L 100g -n ops.disk1.backup xen-vg/ops.disk1

This will seriously degrade the performance of the upgrade process due
to the inefficiencies of disk writes when shadows are present, but it is
worth it to avoid a total screw up.

A. Updating the base FreeBSD system

You cannot use freebsd-update since this is a no-longer-supported release.
So we have to do a build/install from scratch. Start with boss and:

1. Grab some FreeBSD sources and build. This step can be done while your
   testbed is still up and running. We are just building things, not
   installing them yet:

    cd /usr
    sudo svn checkout -q svn://svn0.us-west.freebsd.org/base/releng/10.2 src

   take obsolete (or potentially problematic) options out of /etc/make.conf:

    NO_KERBEROS

   and build the utilities and kernel:

    cd src
    sudo make -j8 buildworld
    # for most places
    sudo make -j8 buildkernel KERNCONF=GENERIC
    # for Utah -- has hacks to handle 4 Xen virtualized disks correctly
    sudo make -j8 buildkernel KERNCONF=VM-GENERIC

   Change the -j8 to whatever is appropriate for your machine (typically,
   1-2x the number of physical processors).

2. Now, turn off the testbed:

    sudo /usr/testbed/sbin/testbed-control shutdown

3. and install the kernel and utilities:

    cd /usr/src
    sudo make installkernel KERNCONF=GENERIC
    sudo make installworld

4. Most painfully, update the startup and other configuration scripts:

    sudo mergemaster -iF

   This is a largely manual process:

   - If it asks you to remove stale files, do so.

   - You will mostly hit 'i' to install. Files you do NOT want to change
     (hit return instead to "leave for later"):

     /etc/crontab
     /etc/group
     /etc/hosts
     /etc/master.passwd
     /etc/newsyslog.conf
     /etc/ntp.conf       # if you have customized it
     /etc/shells
     /etc/ssh/ssh_config
     /etc/ssh/sshd_config
     /etc/sysctl.conf
     /etc/syslog.conf
     /etc/ttys           # if you have configured a serial console

   - do NOT delete what is left of /var/tmp/temproot as you will have
     to manually merge some files.

   - yes, run /usr/bin/newaliases

   - yes, run /usr/bin/cap_mkdb

   - yes, run /usr/sbin/services_mkdb

   - take note of the list of /var/tmp/temproot files that remain.
     In fact, you will probably want to cut and paste it into a file.

5. Manually merge the leftovers from mergemaster.

   IMPORTANT: make sure that /etc/hosts.allow changes got propogated.
   On some sites (those without an external firewall) we setup rules to
   block extenal access to rpcbind and tftpd. The Emulab changes for this
   file probably got automatically merged, but be sure to double check.

   As I say, I stick the list of leftovers in a file and then:

    sudo emacs `cat /tmp/list`

   Then for each of those, I compare the current (Emulab) version with the
   new (temproot) version:

   - For these files:

     /etc/crontab
     /etc/group
     /etc/hosts
     /etc/master.passwd
     /etc/shells
     /etc/sysctl.conf
     /etc/syslog.conf

     the primary differences are Emulab additions at the end. You can just
     use the current Emulab version. However, to make future mergemaster
     runs easier, you will want to also copy over the "$FreeBSD:" header
     line in the early part of the new version of the file and replace the
     corresponding line in yours.

   - /etc/newsyslog.conf: the new version adds some <include> directives
     at the end; copy those into your version. Put them BEFORE the Emulab-added
     sections. (And yes, the Emulab additions should go in a
     /usr/local/etc/newsyslog.conf.d/ file!) Update the "$FreeBSD" header.

   - /etc/ntp.conf: if you made changes, then just keep your version,
     otherwise copy over the new version.

   - /etc/ssh/ssh_config: the only difference should be the VersionAddendum
     string and whatever lines were added by Emulab. Update the VersionAddendum
     string in your version. Update the "$FreeBSD" header.

   - /etc/ssh/sshd_config: there are a couple of commented-out new options
     and nits in the new version. Basically, you can use the new version
     but preserve the setting of PermitRootLogin:
         PermitRootLogin yes
     This setting is absolutely CRITICAL.

   - /etc/ttys: preserve the "console" settings if you changed them.
     Update the "$FreeBSD" header.

   If you were diligent about updating the $FreeBSD headers, then you
   can just re-run mergemaster as before. Tell it to use the existing
   /var/tmp/temproot and the only files it will complain about are the
   ones where you kept your copy without updating the version string.
   For those, you can just type 'd' and delete the temproot version.

6. Reboot boss and make sure everything came up okay.

   Before you do that, if the boss and ops are VMs, go into /boot/loader.conf
   and set:

      # XXX FreeBSD recommends this as a workaround for stability issues
      # when running under Xen.
      vfs.unmapped_buf_allowed=0

   This is a workaround for instabilities seen when running under Xen
   (and boy, have we seen those over the years!)

   After rebooting, you should be running FreeBSD 10.2! The testbed services
   should still be down, that is okay.

   One last thing is to run freebsd-update and pick up any security fixes.
   You should first customize your /etc/freebsd-update.conf and update:

    Components src world kernel

   Take out src if you have no /usr/src tree OR it is an svn clone.
   Take out kernel if you have a custom kernel.

   Then:

    sudo freebsd-update fetch
    sudo freebsd-update install

   There should not be any since you built (in theory) using the most recent
   FreeBSD sources, but you never know. If the kernel got updated, you may
   need to reboot again.

7. Update ops source and binaries.

   The easiest way is to just copy /usr/src and /usr/obj over from your
   boss node:

    cd /usr
    sudo tar cf - src | sudo ssh ops 'cd /usr; tar xf -'
    sudo tar cf - obj | sudo ssh ops 'cd /usr; tar xf -'

   But if you are uncomfortable with this, feel free to repeat steps 1 and 2.
   Either way, then you do:

    cd /usr/src
    sudo make installkernel KERNCONF=GENERIC
    sudo make installworld

8. Do the mergemaster thing on ops.

   Pretty much the same as on boss.

    sudo mergemaster -iF

   - If it asks you to remove stale files, do so.

   - You will mostly hit 'i' to install. Files you do NOT want to change
     (hit return instead to "leave for later"):

     /etc/group
     /etc/hosts
     /etc/mail/aliases
     /etc/master.passwd
     /etc/newsyslog.conf
     /etc/ntp.conf       # if you have customized it
     /etc/shells
     /etc/ssh/ssh_config
     /etc/ssh/sshd_config
     /etc/sysctl.conf
     /etc/syslog.conf
     /etc/ttys           # if you have configured a serial console

   - do NOT delete what is left of /var/tmp/temproot as you will have
     to manually merge some files.

   - yes, run /usr/bin/cap_mkdb

   - yes, run /usr/sbin/services_mkdb

   - take note of the list of /var/tmp/temproot files that remain.
     In fact, you will probably want to cut and paste it into a file.

9. Manually merge the leftovers from mergemaster.

   As I say, I stick the list of leftovers in a file and then:

    sudo emacs `cat /tmp/list`

   Then for each of those, I compare the current (Emulab) version with the
   new (temproot) version:

   - For these files:

     /etc/group
     /etc/hosts
     /etc/mail/aliases
     /etc/master.passwd
     /etc/shells
     /etc/sysctl.conf
     /etc/syslog.conf

     the primary differences are Emulab additions at the end. You can just
     use the current Emulab version. However, to make future mergemaster
     runs easier, you will want to also copy over the "$FreeBSD:" header
     line in the early part of the new version of the file and replace the
     corresponding line in yours.

   - /etc/newsyslog.conf: the new version adds some <include> directives
     at the end; copy those into your version. Put them BEFORE the Emulab-added
     sections. (And yes, the Emulab additions should go in a
     /usr/local/etc/newsyslog.conf.d/ file!) Update the "$FreeBSD" header.

   - /etc/ntp.conf: if you made changes, then just keep your version,
     otherwise copy over the new version.

   - /etc/ssh/ssh_config: the only difference should be the VersionAddendum
     string and whatever lines were added by Emulab. Update the VersionAddendum
     string in your version. Update the "$FreeBSD" header.

   - /etc/ssh/sshd_config: there are a couple of commented-out new options
     and nits in the new version. Basically, you can use the new version
     but preserve the setting of PermitRootLogin:
         PermitRootLogin yes
     This setting is absolutely CRITICAL.

   - /etc/ttys: preserve the "console" settings if you changed them.
     Update the "$FreeBSD" header.

   If you were diligent about updating the $FreeBSD headers, then you
   can just re-run mergemaster as before. Tell it to use the existing
   /var/tmp/temproot and the only files it will complain about are the
   ones where you kept your copy without updating the version string.
   For those, you can just type 'd' and delete the temproot version.

10. Reboot ops and make sure everything came up okay.

   Before you do that, if the boss and ops are VMs, go into /boot/loader.conf
   and set:

      # XXX FreeBSD recommends this as a workaround for stability issues
      # when running under Xen.
      vfs.unmapped_buf_allowed=0

   This is a workaround for instabilities seen when running under Xen
   (and boy, have we seen those over the years!)

   After rebooting, you should be running FreeBSD 10.2! The testbed services
   should still be down, that is okay.

   One last thing is to run freebsd-update and pick up any security fixes.
   You should first customize your /etc/freebsd-update.conf and update:

    Components src world kernel

   Take out src if you have no /usr/src tree OR it is an svn clone.
   Take out kernel if you have a custom kernel.

   Then:

    sudo freebsd-update fetch
    sudo freebsd-update install

   There should not be any since you built (in theory) using the most recent
   FreeBSD sources, but you never know. If the kernel got updated, you may
   need to reboot again.

B. Updating ports/packages

   Unfortunately, this is not as easy as just doing "pkg upgrade".
   the 10.0 port/package situation was "fluid" at best. So we will have to
   uninstall all the old packages and install the new ones.

0. Make note of what emulab packages you have installed.

   pkg info | grep emulab

   Ignore emulab-tftp-hpa if it is installed, it will get installed as a
   dependent of emulab-boss. You will need to make sure you reinstall the
   remaining packages in #4 below.

1. Make a list of the ports you have installed:

   pkg info > boss.pkg.list

   This is mostly to keep track of any ports you may have installed locally.
   Here is one way to figure out what was installed after the initial install.
   Find the date of the most recent emulab-* package install:

   set bdate=`pkg query -x "%t" '^emulab' | sort +1 -nr | head -1`

   List out all the packages newer than that:

   pkg query -e "%t>$bdate" "%n" > boss.pkg.local

   This will give you the list of packages that you may need to reinstall.

   You may want to list the dependencies of each to see what the top-level
   packages are and just install those.

   pkg query -x "%n %v usedby=%#r" `cat boss.pkg.local` | \
       grep 'usedby=0' > boss.pkg.reinstall

2. Remove the old ports

   Since we will be removing sudo, make sure to be root before deinstalling:

    sudo -E ASSUME_ALWAYS_YES=true $SHELL
    pkg unlock pkg
    pkg delete -af

   Reinstall the pkg tool:

    pkg bootstrap

   You may get "Certificate verification failed" messages (depending on
   who your CA is), but it should still work. To deal with any certificate
   errors do:

    pkg install ca_root_nss

   After this, everything should be peachy.

3. Create an Emulab repository description

   cat <<END >/etc/pkg/Emulab.conf
Emulab: {
  url: "https://www.emulab.net/FreeBSD/10.2/packages",
  mirror_type: NONE,
  enabled: yes
}
END

4. Install the latest packages

4a. If you have a network connection and can reach www.emulab.net:

    pkg install -r Emulab emulab-boss
    pkg install -r Emulab emulab-protogeni	# if installed previously
    pkg install -r Emulab emulab-extras

  REALLY, REALLY IMPORTANT: the latest perl port does not install the
  /usr/bin/perl link which we use heavily in Emulab scripts. Ditto for
  python and the /usr/local/bin/python link. Get them back with:

    ln -sf /usr/local/bin/perl5 /usr/bin/perl    
    ln -sf /usr/local/bin/python2 /usr/local/bin/python

4b. Modified instructions for installing latest packages w/o a connection
    to the mothership

    cd ~/packages
    sudo pkg add pkg-1.5.6.txz
    sudo pkg add ca_root_nss-3.19.3.txz
    sudo pkg add emulab-boss-6.2.txz
    sudo pkg add emulab-protogeni-6.2.txz
    sudo pkg add emulab-extras-6.2.txz

    sudo pkg annotate -ay -A repository Emulab

5. Repeat steps 1-3 for ops.

   pkg info > ops.pkg.list
   set bdate=`pkg query -x "%t" '^emulab' | sort +1 -nr | head -1`
   pkg query -e "%t>$bdate" "%n" > ops.pkg.local
   pkg query -x "%n %v usedby=%#r" `cat ops.pkg.local` | \
       grep 'usedby=0' > ops.pkg.reinstall

   sudo -E ASSUME_ALWAYS_YES=true $SHELL
   pkg delete -af

   pkg bootstrap
   pkg install ca_root_nss

   cat <<END >/etc/pkg/Emulab.conf
Emulab: {
  url: "https://www.emulab.net/FreeBSD/10.2/packages",
  mirror_type: NONE,
  enabled: yes
}
END

6. Install new packages on ops

    pkg install -r Emulab emulab-ops
    pkg install -r Emulab emulab-fs		# if installed previously
    pkg install -r Emulab emulab-extras

  REALLY, REALLY IMPORTANT: the latest perl port does not install the
  /usr/bin/perl link which we use heavily in Emulab scripts. Ditto for
  python and the /usr/local/bin/python link. Get them back with:

    ln -sf /usr/local/bin/perl5 /usr/bin/perl    
    ln -sf /usr/local/bin/python2 /usr/local/bin/python

7. Reboot boss and ops and make sure they come back up okay.

C. Update Emulab software

1. Make sure your Emulab sources are up to date.

   You must use the emulab-devel repository at this point as only it has
   the necessary changes to support FreeBSD 10.2. If you don't already
   have an emulab-devel repo, clone it with:

   git clone git://git-public.flux.utah.edu/emulab-devel.git
     or
   git clone http://git-public.flux.utah.edu/git/emulab-devel.git

   Make sure to copy over your existing defs-* file to the new source
   tree.

2. Reconfigure, rebuild, and reinstall the software.

   You want everything to be built against the new ports and libraries.
   In your build tree, look at config.log to see how it was configured
   and then:

      cd <builddir>
      sudo rm -rf *
      <run the configure line>

      # on ops -- do this first
      sudo gmake opsfs-install

      # on boss -- do this after ops
      sudo gmake all boss-install 

   The reason for the ops install is that, while boss-install updates
   most of the ops binaries/libraries via NFS, there are some that it
   doesn't. So by doing a separate build/install on ops, you are
   guaranteed to catch everything. But be sure to do the opsfs-install
   before the boss-install.

3. Re-enable Emulab services:

   sudo /usr/testbed/sbin/testbed-control boot

4. Reboot boss and ops again!
