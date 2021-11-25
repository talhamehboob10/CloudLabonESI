#!/usr/bin/perl -w
#
# Copyright (c) 2003-2021 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#
#
# A big set of variables that are common to the installation scripts.
#
package installvars;
use strict;
# Avoid having to predefine everything.
no strict "vars";
use Exporter;
use vars qw(@ISA $SYMLIST);
@ISA    = qw(Exporter);
@EXPORT = qw();

# These are set in the driver script from command line args.
$domakes     = 0;
$packagedir  = "";
$password    = undef;

# Version of FreeBSD.
$FBSD_MAJOR = 4;
$FBSD_MINOR = 10;
if (`uname -r` =~ /^(\d+)\.(\d+)/) {
    $FBSD_MAJOR = $1;
    $FBSD_MINOR = $2;
}
else {
    die("Could not determine what version of FreeBSD you are running!\n");
}
$FBSD_ARCH = "i386";
if (`uname -m` =~ /^(\S+)$/) {
    $FBSD_ARCH = $1;
}
else {
    die("Could not determine what architecutre FreeBSD is running on!\n");
}

#
# The meta-ports (name and version) that drag in all the dependancies for
# a boss node. These are OS dependent as we upgrade.
#
$BOSS_PORT = "emulab-boss-1.8";
$OPS_PORT  = "emulab-ops-1.4"; 
$FS_PORT   = "emulab-fs-1.4";
if ($FBSD_MAJOR > 4) {
    if ($FBSD_MAJOR == 12) {
	    $BOSS_PORT = "emulab-boss-8.1";
	    $OPS_PORT = "emulab-ops-8.1";
	    $FS_PORT = "emulab-fs-8.1";
    } elsif ($FBSD_MAJOR == 11) {
	if ($FBSD_MINOR <= 1) {
	    $BOSS_PORT = "emulab-boss-7.1";
	    $OPS_PORT = "emulab-ops-7.1";
	    $FS_PORT = "emulab-fs-7.1";
	} else {
	    my $ver = "7.$FBSD_MINOR";
	    $BOSS_PORT = "emulab-boss-$ver";
	    $OPS_PORT = "emulab-ops-$ver";
	    $FS_PORT = "emulab-fs-$ver";
	}
    } elsif ($FBSD_MAJOR == 10 && $FBSD_MINOR > 2) {
	$BOSS_PORT = "emulab-boss-6.3";
	$OPS_PORT = "emulab-ops-6.3";
	$FS_PORT = "emulab-fs-6.3";
    } elsif ($FBSD_MAJOR == 10 && $FBSD_MINOR > 1) {
	$BOSS_PORT = "emulab-boss-6.2";
	$OPS_PORT = "emulab-ops-6.2";
	$FS_PORT = "emulab-fs-6.2";
    } elsif ($FBSD_MAJOR == 10 && $FBSD_MINOR > 0) {
	$BOSS_PORT = "emulab-boss-6.1";
	$OPS_PORT = "emulab-ops-6.1";
	$FS_PORT = "emulab-fs-6.1";
    } elsif ($FBSD_MAJOR > 9) {
	$BOSS_PORT = "emulab-boss-6.0";
	$OPS_PORT = "emulab-ops-6.0";
	$FS_PORT = "emulab-fs-6.0";
    } elsif ($FBSD_MAJOR == 9 && $FBSD_MINOR > 1) {
	$BOSS_PORT = "emulab-boss-5.1";
	$OPS_PORT = "emulab-ops-5.1";
	$FS_PORT = "emulab-fs-5.1";
    } elsif ($FBSD_MAJOR > 8 || ($FBSD_MAJOR == 8 && $FBSD_MINOR > 2)) {
	$BOSS_PORT = "emulab-boss-5.0";
	$OPS_PORT = "emulab-ops-5.0";
	$FS_PORT = "emulab-fs-5.0";
    } elsif ($FBSD_MAJOR > 7) {
	$BOSS_PORT = "emulab-boss-4.0";
	$OPS_PORT = "emulab-ops-4.0";
	$FS_PORT = "emulab-fs-4.0";
    } elsif ($FBSD_MAJOR == 7 && $FBSD_MINOR > 2) {
	$BOSS_PORT = "emulab-boss-3.1";
	$OPS_PORT = "emulab-ops-3.1";
	$FS_PORT = "emulab-fs-3.1";
    } elsif ($FBSD_MAJOR == 7) {
	$BOSS_PORT = "emulab-boss-3.0";
	$OPS_PORT = "emulab-ops-3.0";
	$FS_PORT = "emulab-fs-3.0";
    } elsif ($FBSD_MAJOR == 6 && $FBSD_MINOR > 2) {
	$BOSS_PORT = "emulab-boss-2.1";
	$OPS_PORT = "emulab-ops-2.1";
	$FS_PORT = "emulab-fs-2.1";
    } else {
	$BOSS_PORT = "emulab-boss-2.0";
	$OPS_PORT = "emulab-ops-2.0";
	$FS_PORT = "emulab-fs-2.0";
    }
}

# PHP5 is the only alternative at the moment and only for newer OSes
$PHP_VERSION = 4;
$PHP_PORT = "php4-extensions-1.0";
if ($FBSD_MAJOR > 11 || ($FBSD_MAJOR == 11 && $FBSD_MINOR >= 3)) {
    $PHP_VERSION = 7;
    $PHP_PORT = "";
} elsif ($FBSD_MAJOR > 7 || ($FBSD_MAJOR == 7 && $FBSD_MINOR > 2)) {
    $PHP_VERSION = 5;
    # there is no longer an explict extensions package
    if ($FBSD_MAJOR == 10 && $FBSD_MINOR > 0) {
	$PHP_PORT = "php56";
    } elsif ($FBSD_MAJOR > 9 || ($FBSD_MAJOR == 9 && $FBSD_MINOR > 1)) {
	$PHP_PORT = "php5-extensions-1.7";
    } elsif ($FBSD_MAJOR > 8 || ($FBSD_MAJOR == 8 && $FBSD_MINOR > 2)) {
	$PHP_PORT = "php5-extensions-1.6";
    } elsif ($FBSD_MAJOR > 7) {
	$PHP_PORT = "php5-extensions-1.4";
    } else {
	$PHP_PORT = "php5-extensions-1.3";
    }
}

# XXX temporary for tftp
$TFTPD_PKG	  = "emulab-tftp-hpa-0.48";
if ($FBSD_MAJOR > 10 || ($FBSD_MAJOR == 10 && $FBSD_MINOR > 0)) {
    $TFTPD_PKG = "emulab-tftp-hpa-5.2";
}

# XXX temporary for perl DBD mysql access (only needed for FBSD7 and below)
$P5DBD_PKG	  = "p5-DBD-mysql50-3.0002";

# Lots of patches
$STL_PATCH		= "$main::TOP_SRCDIR/patches/g++.patch";
$M2CRYPTO_PATCH		= "$main::TOP_SRCDIR/patches/m2crypto.patch";
$MYSQL_PM_PATCH		= "$main::TOP_SRCDIR/patches/Mysql.pm.patch";
$PHP4_PATCH		= "$main::TOP_SRCDIR/patches/php4-Makefile.patch";
$SELFLOAD_PATCH		= "$main::TOP_SRCDIR/patches/SelfLoader.patch";

#
# Version dependent python-fu 
#
$PYM2_PKG = "py25-m2crypto-0.19.1";
$PY_VER   = "python2.5";
$PY_PKGPREFIX = "py27";
if ($FBSD_MAJOR > 11) {
    $PYM2_PKG = "";
    $PY_VER = "python3.8";
    $PY_PKGPREFIX = "py38";
} elsif ($FBSD_MAJOR == 11 && $FBSD_MINOR > 3) {
    $PYM2_PKG = "";
    $PY_VER = "python3.7";
    $PY_PKGPREFIX = "py37";
} elsif ($FBSD_MAJOR > 10 || ($FBSD_MAJOR == 10 && $FBSD_MINOR > 0)) {
    $PYM2_PKG = "py27-m2crypto-0.22.3";
    $PY_VER = "python2.7";
} elsif ($FBSD_MAJOR > 9) {
    $PYM2_PKG = "py27-m2crypto-0.21.1_1";
    $PY_VER = "python2.7";
} elsif ($FBSD_MAJOR > 8 || ($FBSD_MAJOR == 8 && $FBSD_MINOR > 2)) {
    $PYM2_PKG = "py27-m2crypto-0.21.1";
    $PY_VER = "python2.7";
} elsif ($FBSD_MAJOR > 7 || ($FBSD_MAJOR == 7 && $FBSD_MINOR > 2)) {
    $PYM2_PKG = "py26-m2crypto-0.20";
    $PY_VER = "python2.6";
}
# XXX temporary until someone extracts their head from the dark regions
$EASYINSTALL		= "/usr/local/bin/easy_install";

# These names are for the scripts.
$BOSS_SERVERNAME	= "boss";
$OPS_SERVERNAME 	= "ops";
$FS_SERVERNAME		= "fs";

# Should be configure variable
$TBADMINGID		= 101;

$TBROOT			= "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
$PREFIX			= $TBROOT;

$MAINSITE		= 0;
$PGENISUPPORT		= 1;
$PROTOGENI_GENIRACK     = 0;
$CONFIG_TARGETSYS       = 1;
$TARGETSYS_TARGET       = "UMASS";
$PORTAL_ENABLE          = 1;
$ELABINELAB		= 0;
$ELABINELAB_MAILTARGET	= "";
$DBNAME			= "tbdb";
$ERRORLOG_DBNAME	= "errorlog";
$FRISADDR		= '239.67.170';

$HAVE_XERCES		= "";
$MAILMANSUPPORT		= 0;
$WINSUPPORT		= 0;

$OURDOMAIN		= 'cloudlab.umass.edu';
$USERNODE		= 'ops.cloudlab.umass.edu';
$FSNODE			= 'ops.cloudlab.umass.edu';
$BOSSNODE		= 'boss.cloudlab.umass.edu';
$WWWHOST		= 'www.cloudlab.umass.edu';
$MAILERNODE		= 'ops';
$BOSSNODE_IP		= '198.22.255.3';
$USERNODE_IP		= '198.22.255.4';
$FSNODE_IP		= '198.22.255.4';
$CONTROL_NETWORK	= "198.22.255.0";
$CONTROL_NETMASK	= "255.255.255.0";
$PUBLIC_NETMASK		= "255.255.255.0";
$NTPSERVER		= "ops";
$LOGFACIL		= 'local5';
$QUOTA_FSLIST		= '';
$OURTIMEZONE	        = "America/Denver";
$NODECONSOLE		= "sio2";
$MFSVERSION		= "11-64";

$LOGDIR			= "$TBROOT/log";
$ETCDIR			= "$PREFIX/etc";
$LIBDIR			= "$PREFIX/lib";
$WAP			= "$TBROOT/sbin/withadminprivs";
$TESTBED_CONTROL	= "$TBROOT/sbin/testbed-control";

$ELVIN_COMPAT		= 0;
$MAILMANSUPPORT		= 0;
$CVSSUPPORT		= 0;
$BUGDBSUPPORT		= 0;
$WIKISUPPORT		= 0;
$NOSHAREDFS		= 0;
$DISABLE_EXPORTS_SETUP  = 0;
# Are we a VM on boss?
$OPSVM_ENABLE		= 0;
# mrouted no longer needed; replaced by IGMP querier in mfrisbeed
$NEEDMROUTED		= 0;
$ARCHSUPPORT		= 0;
$BROWSER_CONSOLE_ENABLE = 1;
$BROWSER_CONSOLE_PROXIED= 0;
$BROWSER_CONSOLE_WEBSSH = 1;
$WITHZFS		= 1;
$WITHAMD		= 1;
$IMAGEUPLOADTOFS	= 0;

#
# Python/Perl paths
#
# EMULAB* are the paths we expect and use in '#!'
# PORT* are the paths that the ports install and should always exist
#
# We make sure the former is symlinked to the latter.
#
$EMULAB_PERL_PATH	= "/usr/bin/perl";
$EMULAB_PYTHON_PATH	= "/usr/local/bin/python";
$PORT_PERL_PATH		= "/usr/local/bin/perl5";
$PORT_PYTHON_PATH	= "/usr/local/bin/python2";
$PORT_PYTHON_PATH2	= "/usr/local/bin/python2.7";
if ($FBSD_MAJOR > 11) {
    $PORT_PYTHON_PATH	= "/usr/local/bin/python3";
    $PORT_PYTHON_PATH2	= "/usr/local/bin/python3.7";
}

#
# Some programs we use
#
$CHGRP			= "/usr/bin/chgrp";
$CHMOD			= "/bin/chmod";
$MKDIR			= "/bin/mkdir";
$TOUCH			= "/usr/bin/touch";
$CHOWN			= "/usr/sbin/chown";
$PW			= "/usr/sbin/pw";
$PATCH			= "/usr/bin/patch";
if ($FBSD_MAJOR >= 10) {
    $PATCH		.= " --posix";
}
$CAT			= "/bin/cat";
$NEWALIASES		= "/usr/bin/newaliases";
$SH			= "/bin/sh";
$PWD			= "/bin/pwd";
$CP			= "/bin/cp";
$MV			= "/bin/mv";
$ENV			= "/usr/bin/env";
$MOUNT			= "/sbin/mount";
$TAR			= "/usr/bin/tar";
$MD5			= "/sbin/md5";
$SSH_KEYGEN		= "/usr/bin/ssh-keygen";
$SUDO			= "/usr/local/bin/sudo";
$GMAKE			= "/usr/local/bin/gmake";
$MYSQL			= "/usr/local/bin/mysql";
$QUOTAON		= "/usr/sbin/quotaon";
$SSH_INIT		= "/usr/bin/ssh -2";
$SCP_INIT		= "/usr/bin/scp -2";
$SSH			= "/usr/bin/ssh -2";
$SCP			= "/usr/bin/scp -2";
#
# XXX keep 4.x ElabInElab install limping along...
#
if ($FBSD_MAJOR == 4) {
    $SCP_INIT = "/usr/bin/scp -oProtocol=1";
    $SCP =      "/usr/bin/scp -oProtocol=2";
}

$PORTSDIR		= "/usr/ports";
$PORTSMISCDIR		= "$PORTSDIR/misc";
$LIST_DIR		= "/etc/mail/lists";
$ALIASES_FILE           = "/etc/mail/aliases";
$VARRUN			= "/var/run";
$RCDIR			= "/usr/local/etc/rc.d";
$NAMED_DIR		= "/etc/namedb";
$RESOLVECONF		= "/etc/resolv.conf";
$FSTAB			= "/etc/fstab";
$RCCONF			= "/etc/rc.conf";
$HOSTS			= "/etc/hosts";
$LOCAL_HOSTNAMES	= "/etc/mail/local-host-names";
$EXPORTS_FILE		= "/etc/exports";
$EXPORTS_HEAD		= "$EXPORTS_FILE.head";
$SYSLOG_CONF		= "/etc/syslog.conf";
$NEWSYSLOG_CONF		= "/etc/newsyslog.conf";
$SUDOERS		= "/usr/local/etc/sudoers";
$SSHD_CONFIG		= "/etc/ssh/sshd_config";
$CRONTAB		= "/etc/crontab";
$TIPLOG_DIR		= "/var/log/tiplogs";
$OPSWWWDIR		= "/usr/local/www/data";
$WWWDIR			= "$PREFIX/www";
$TBBASE			= "https://www.cloudlab.umass.edu";
$THISHOMEBASE           = "UMASS";
$AUTHKEYS		= "/root/.ssh/authorized_keys";
$RCCAPTURE		= "$PREFIX/etc/rc.capture";
$RCLOCAL		= "/etc/rc.local";
$PHP_INI		= "/usr/local/etc/php.ini";
$PHP_CONF		= "/usr/local/etc/php.conf";
$SENDMAIL_CF		= "/etc/mail/sendmail.cf";
$INETD_CONF		= "/etc/inetd.conf";
$ETCSSH			= "/etc/ssh";
$SSH_CONFIG	        = "$ETCSSH/ssh_config";
$LOADER_CONF		= "/boot/loader.conf";
$SYSCTL_CONF		= "/etc/sysctl.conf";

$GROUPROOT		= "/groups";
$USERROOT		= "/users";
$SCRATCHROOT		= "";
$SHAREROOT		= "/share";
$PROJROOT		= "/proj";

$TBOPSEMAIL		= "testbed-ops\@ops.cloudlab.umass.edu";
$TBTESTSUITEEMAIL	= "testbed-testsuite\@ops.cloudlab.umass.edu";

# For installing mysqld
$MYSQLD			= "/usr/local/libexec/mysqld";
$MYSQLADMIN		= "/usr/local/bin/mysqladmin";
$MYSQLSHOW		= "/usr/local/bin/mysqlshow";
$MYSQLDUMP		= "/usr/local/bin/mysqldump";
$MYSQLINSTALL		= "/usr/local/bin/mysql_install_db";
$MYSQLDBDIR		= "/var/db/mysql";
$MYSQL_LOGDIR		= "$LOGDIR/mysql";
$MYSQL_CNF		= "/usr/local/etc/mysql/my.cnf";

$PROTOUSER		= "elabman";
$CHECKUPUSER		= "elabckup";

$INSTALL_APACHE_CONFIG	= "/usr/local/etc/apache";
$APACHE_VERSION		= "1.3";
$APACHE_START_COMMAND	= "/usr/local/etc/rc.d/apache.sh";
$APACHE_ETCDIR		= "$INSTALL_APACHE_CONFIG";
$HTTPD_CONF		= "$APACHE_ETCDIR/httpd.conf";
$HTTPD_GENI_CONF	= "$APACHE_ETCDIR/httpd-geni.conf";
$APACHE_CERTPEM		= "apache.pem";
$APACHE_KEYPEM		= "apache.key";
$APACHE_CERTFILE	= "$APACHE_ETCDIR/ssl.crt/www.${OURDOMAIN}.crt";
$APACHE_KEYFILE		= "$APACHE_ETCDIR/ssl.key/www.${OURDOMAIN}.key";
$APACHE_CERTPEM_OPS	= "apache-ops.pem";
$APACHE_KEYPEM_OPS	= "apache-ops.key";
$APACHE_CERTFILE_OPS	= "$APACHE_ETCDIR/ssl.crt/${USERNODE}.crt";
$APACHE_KEYFILE_OPS	= "$APACHE_ETCDIR/ssl.key/${USERNODE}.key";

$PROTOGENI_RPCNAME	= "www.cloudlab.umass.edu";
$PROTOGENI_RPCPORT	= "12369";
$PROTOGENI_EMAIL        = "geni-dev-utah\@flux.utah.edu";

$DHCPD_CONF		= "/usr/local/etc/dhcpd.conf";
$DHCPD_TEMPLATE		= "/usr/local/etc/dhcpd.conf.template";
$DHCPD_LEASES		= "/var/db/dhcpd.leases";
$DHCPD_MAKECONF		= "$TBROOT/sbin/dhcpd_makeconf";
$NAMED_SETUP		= "$TBROOT/sbin/named_setup";

$BATCHEXP		= "$PREFIX/bin/batchexp";
$ADDPUBKEY		= "$PREFIX/sbin/addpubkey";
$TBACCT			= "$PREFIX/sbin/tbacct";
$GENTOPOFILE		= "$PREFIX/libexec/gentopofile";
$UPDATESITEVARS		= "$PREFIX/sbin/update_sitevars";
$IMAGEIMPORT            = "$PREFIX/sbin/image_import";
$IMAGEVALIDATE          = "$PREFIX/sbin/imagevalidate";

$PROTOUSER_DSAKEY	= "$main::TOP_SRCDIR/install/elabman_dsa.pub";
$PROTOUSER_RSAKEY	= "$main::TOP_SRCDIR/install/elabman_rsa.pub";
$ROOT_PRIVKEY		= "/root/.ssh/id_rsa";
$ROOT_PUBKEY		= "$ROOT_PRIVKEY.pub";
$ROOT_AUTHKEY		= "/root/.ssh/authorized_keys";
$ROOT_DSA_PRIVKEY	= "/root/.ssh/id_dsa";
$ROOT_DSA_PUBKEY	= "$ROOT_DSA_PRIVKEY.pub";
# Stub RSA private key for switch expect module.
$SWITCH_RSA_PRIVKEY     = "$PREFIX/etc/switch_sshrsa";
$SWITCH_RSA_PUBKEY      = "$PREFIX/etc/switch_sshrsa.pub";

$INIT_PRIVKEY		= "$main::TOP_SRCDIR/install/id_rsa";
$INIT_PUBKEY		= "$main::TOP_SRCDIR/install/id_rsa.pub";
$CACERT			= "$TBROOT/etc/emulab.pem";
$EMULAB_PEM		= "emulab.pem";
$EMULAB_PUB		= "emulab.pub";
$CLIENT_PEM		= "client.pem";
$CTRLNODE_PEM		= "ctrlnode.pem";
$ETC_EMULAB_DIR		= "/etc/emulab";

$SMBCONF_FILE		= "/usr/local/etc/smb.conf";
$SMBCONF_HEAD		= "$SMBCONF_FILE.head";

$TFTP_DIR	        = "$PREFIX/tftpboot";
$TFTP_PROJ_DIR		= "$TFTP_DIR/proj";
$IMAGEKEYS_DIR	        = "$ETCDIR/image_hostkeys";

$DEFAULTIMAGESITEVAR    = "general/default_imagename";
$IMAGEPASSWORDSITEVAR   = "images/root_password";

$MAILMANDIR		= "/usr/local/mailman";
$MAILMANCFG		= "$MAILMANDIR/Mailman/mm_cfg.py";

$SHAREDIR		= "/share";
$SCRATCHDIR		= "";

$OUTERBOSS_XMLRPCPORT   = "3069";

@OPS_NAMES		= ($USERNODE, "users", "ops");
@MAILING_LISTS		= ("testbed-ops\@ops.cloudlab.umass.edu","testbed-logs\@ops.cloudlab.umass.edu","testbed-www\@ops.cloudlab.umass.edu",
			   "testbed-approval\@ops.cloudlab.umass.edu","testbed-audit\@ops.cloudlab.umass.edu",
			   "testbed-stated\@ops.cloudlab.umass.edu", "testbed-testsuite\@ops.cloudlab.umass.edu",
			   "testbed-errors\@ops.cloudlab.umass.edu", "testbed-automail\@ops.cloudlab.umass.edu");
@LOCAL_MAILING_LISTS    = grep(/$OURDOMAIN$/, @MAILING_LISTS);

$USERSVAR_MOUNTPOINT	= "$PREFIX/usersvar";
$OPSDIR_MOUNTPOINT	= "$PREFIX/opsdir";
$OPSVM_MOUNTPOINT	= "/ops";

@MOUNTPOINTS		= ($USERROOT, $PROJROOT, $GROUPROOT);
if ($SHAREDIR) {
    push(@MOUNTPOINTS, $SHAREROOT);
}
if ($SCRATCHDIR) {
    push(@MOUNTPOINTS, $SCRATCHROOT);
}

# ElabinElab.
$OUTER_BOSS		 = '';
if ($OUTER_BOSS eq '') {
    $OUTER_BOSS = "www.emulab.net";
}

# Firewall stuff
$FIREWALL_BOSS		= 0;
$FIREWALL_OPS		= 0;
$FIREWALL_BOSS_RULES    = "/etc/boss.ipfw";
$FIREWALL_OPS_RULES     = "/etc/ops.ipfw";

sub ISBOSSNODE($)	{ return ($_[0] eq $BOSS_SERVERNAME) ? 1 : 0; }
sub ISOPSNODE($)	{ return ($_[0] eq $OPS_SERVERNAME) ? 1 : 0; }
sub ISFSNODE($)		{ return ($_[0] eq $FS_SERVERNAME) ? 1 : 0; }

#
# Is the given server the FS
#
sub ISFS($)
{
    my ($server) = @_;

    if ($server eq $BOSS_SERVERNAME) {
	return ($BOSSNODE_IP eq $FSNODE_IP) ? 1 : 0;
    }
    elsif ($server eq $OPS_SERVERNAME) {
	return ($USERNODE_IP eq $FSNODE_IP) ? 1 : 0;
    }
    elsif ($server eq $FS_SERVERNAME) {
	return 1;
    }
    return 0;
}

#
# The point of this code is to export every single symbol in this
# file to the caller, without having to list them all.
#
sub importup($)
{
    my ($caller) = @_;

    no strict 'refs';

    while (my ($name, $symbol) = each %{__PACKAGE__ . '::'}) {
        next if      $name eq 'BEGIN';    # don't export BEGIN blocks
        next if      $name eq 'import';   # don't export this sub

        my $imported = $caller . '::' . $name;
        *{ $imported } = \*{ $symbol };
    }
}

sub import {
    return importup(caller());
}

1;
