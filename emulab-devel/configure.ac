#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
AC_PREREQ([2.68])

AC_INIT
AC_CONFIG_SRCDIR([Makeconf.in])
AC_CONFIG_AUX_DIR(autoconf)
AC_PREFIX_DEFAULT(/usr/testbed)
AC_CONFIG_HEADER(config.h)
AC_CANONICAL_HOST

# We use separate source and obj trees in Emulab.  Configuring in a source
# tree messes it up, so throw an error.
#
# Check that $srcdir, (which defaults to the argv[0] path to the configure
# script,) is different from the current directory.
#
if test `(cd $srcdir; pwd)` = `pwd`; then
    if test "$ac_srcdir_defaulted" = yes; then
	AC_MSG_ERROR(
	    [You are running the configure script in the current directory.
Output from configure must go into an Emulab obj tree, not a source tree!
cd to the top of an obj tree, and run the configure in your source tree.])
    else
	AC_MSG_ERROR(
	    [You specified --srcdir= to be the current directory.
Output from configure should go into an Emulab obj tree, not a source tree!
cd to the top of an obj tree, and run the configure in your source tree.
Then --srcdir= will be unnecessary.])
    fi
fi
#
# Double-check that there isn't a Makeconf.in (the UNIQUE-FILE-IN-SOURCE-DIR)
# in the current directory.
#
if test -f $ac_unique_file; then
    AC_MSG_ERROR([The current directory is a source tree containing $ac_unique_file .
Output from configure should go into an Emulab obj tree, not a source tree!
cd to the top of an obj tree, and run the configure in your source tree.])
fi

for tbarch in arm/3.4.1; do
    PATH="/usr/local/$tbarch/bin:${PATH}"
done

if test x"${JAVA_HOME}" != x""; then
    PATH="${JAVA_HOME}/bin:${PATH}"
else
    for jdk in /usr/local/jdk*; do
	PATH="${jdk}/bin:${PATH}"
	break
    done
fi

AC_SUBST(PATH)

CPPFLAGS="-I/usr/local/include"

# BEGIN Python detection. For the event library.
AC_PATH_PROGS(PYTHON, python python2.7 python2.6 python2.5 python2.4 python2.3 python2.2 python3)

if test x"$PYTHON" = x""; then
    AC_MSG_ERROR([python not detected])
fi

PYTHON_VERSION=`${PYTHON} -V 2>&1 | cut -d ' ' -f 2 | cut -d '.' -f 1,2 | head -1`
PYTHON_PATH=`dirname ${PYTHON}`
if test ! -d "$PYTHON_PATH/include"; then
    PYTHON_PATH=`dirname ${PYTHON_PATH}`
fi
PYTHON_INCLUDE="${PYTHON_PATH}/include/python${PYTHON_VERSION}"
if test ! -d "$PYTHON_INCLUDE" -a -d "${PYTHON_INCLUDE}m"; then
      PYTHON_INCLUDE="${PYTHON_INCLUDE}m"
fi
CPPFLAGS="${CPPFLAGS} -I${PYTHON_INCLUDE}"
AC_CHECK_HEADERS([Python.h],
		 [],
		 [AC_MSG_WARN("Cannot find Python.h in ${PYTHON_INCLUDE}")])
AC_SUBST(PYTHON_INCLUDE)
# END Python detection.

# On Linux, rpc/rpc.h may be in another place, e.g. for tirpc,
# /usr/include/tirpc .
RPC_INCLUDE=""
RPC_CPPFLAGS=""
old_CPPFLAGS="$CPPFLAGS"
for rpcpath in "" "/usr/include/tirpc" ; do
    if ! test x"$rpcpath" = x"" ; then
        CPPFLAGS="$old_CPPFLAGS -I$rpcpath"
    fi
    AC_CHECK_HEADERS([rpc/rpc.h],[RPC_INCLUDE="$rpcpath"],[])
    if test "x$ac_cv_header_rpc_rpc_h" = xyes ; then
        break;
    fi
    $as_unset ac_cv_header_rpc_rpc_h
done
# Final "check" so we can return an error message.
if ! test x"${RPC_INCLUDE}" = x"" ; then
    RPC_CPPFLAGS="-I${RPC_INCLUDE}"
fi
CPPFLAGS="$old_CPPFLAGS $RPC_CPPFLAGS"
if ! test "x$ac_cv_header_rpc_rpc_h" = xyes ; then
    AC_CHECK_HEADERS([rpc/rpc.h],[],[AC_MSG_ERROR("Cannot find rpc/rpc.h")])
fi
CPPFLAGS="$old_CPPFLAGS"
AC_SUBST(RPC_CPPFLAGS)

# Find perl for gettimezone invocation below
AC_PATH_PROGS(PERL, perl perl5)
if test x"$PERL" = x""; then
    AC_MSG_ERROR([perl not detected])
fi

AC_CHECK_TOOL(CC,gcc)
AC_CHECK_TOOL(CXX,g++)
AC_CHECK_TOOL(AR,ar)
AC_CHECK_TOOL(RANLIB,ranlib)
AC_CHECK_TOOL(STRIP,strip)

AC_EXEEXT

AC_PATH_PROG(DIG,dig)
AC_PATH_PROG(ELVIN_CONFIG,elvin-config)
AC_PATH_PROG(JAVAC,javac)
AC_PATH_PROG(JAR,jar)
AC_PATH_PROG(NC,nc)
AC_PATH_PROG(SUDO,sudo)
AC_PATH_PROG(UUIDGEN,uuidgen)

AC_CHECK_TOOL(SSH,ssh)

AC_CHECK_FUNCS(srandomdev)

AC_SUBST(optional_subdirs)

#
# These get defined in the definitions file (--with-TBDEFS).
# NB: See AC_DEFINE_UNQUOTED() calls below, if you want a variable
# to appear in config.h.
#
AC_SUBST(TBDBNAME)
AC_SUBST(TBERRORLOGDBNAME)
AC_SUBST(TBADMINGROUP)
AC_SUBST(DELAYCAPACITY)
AC_SUBST(IPBASE)
AC_SUBST(JAILIPBASE)
AC_SUBST(JAILIPMASK)
AC_SUBST(BOSSNODE)
AC_SUBST(USERNODE)
AC_SUBST(FSNODE)
AC_SUBST(EVENTSERVER)
AC_SUBST(BOSSEVENTPORT)
AC_SUBST(OURDOMAIN)
AC_SUBST(USERSROOT_DIR)
AC_SUBST(PROJROOT_DIR)
AC_SUBST(GROUPSROOT_DIR)
AC_SUBST(SCRATCHROOT_DIR)
AC_SUBST(SHAREROOT_DIR)
AC_SUBST(FSDIR_PROJ)
AC_SUBST(FSDIR_GROUPS)
AC_SUBST(FSDIR_USERS)
AC_SUBST(FSDIR_SHARE)
AC_SUBST(FSDIR_SCRATCH)
AC_SUBST(FS_WITH_QUOTAS)
AC_SUBST(TRACK_INTERSWITCH_BANDWIDTH)
AC_SUBST(TIMESTAMPS)
AC_SUBST(OURTIMEZONE)
AC_SUBST(NODECONSOLE)
AC_SUBST(MFSVERSION)
AC_SUBST(UNIFIED_BOSS_AND_OPS)
AC_SUBST(DISABLE_NSE)
AC_SUBST(DISABLE_DHCPD_INSTALL)
AC_SUBST(DISABLE_NAMED_INSTALL)
AC_SUBST(DISABLE_NAMED_SETUP)
AC_SUBST(DISABLE_EXPORTS_SETUP)
AC_SUBST(DISABLE_FSNODE_CHFLAGS)
AC_SUBST(DISABLE_EVENT_SCHED)
AC_SUBST(CLIENT_ETCDIR)
AC_SUBST(CLIENT_BINDIR)
AC_SUBST(CLIENT_VARDIR)
AC_SUBST(CLIENT_MANDIR)
AC_SUBST(SNMP_RW_COMMUNITY)
AC_SUBST(WWWHOST)
AC_SUBST(WWW)
AC_SUBST(TBBASE)
AC_SUBST(TBDEFS)
AC_SUBST(TBDOCBASE)
AC_SUBST(TBWWW)
AC_SUBST(THISHOMEBASE)
AC_SUBST(TBSECURECOOKIES)
AC_SUBST(TBCOOKIESUFFIX)
AC_SUBST(TBAUTHDOMAIN)
AC_SUBST(TBAUTHTIMEOUT)
AC_SUBST(TBMAINSITE)
AC_SUBST(FANCYBANNER)
AC_SUBST(SFSSUPPORT)
AC_SUBST(ELABINELAB)
AC_SUBST(ELABINELAB_MAILTARGET)
AC_SUBST(OUTERBOSS_NODENAME)
AC_SUBST(OUTERBOSS_XMLRPCPORT)
AC_SUBST(OUTERBOSS_SSLCERTNAME)
AC_SUBST(SUBBOSS_SSLCERTNAME)
AC_SUBST(PLABSUPPORT)
AC_SUBST(PUBSUPPORT)
AC_SUBST(WIKISUPPORT)
AC_SUBST(MAILMANSUPPORT)
AC_SUBST(BUGDBSUPPORT)
AC_SUBST(OPSDBSUPPORT)
AC_SUBST(NFSTRACESUPPORT)
AC_SUBST(NTPSERVER)
AC_SUBST(PROJECTMAILLISTS)
AC_SUBST(EXTERNAL_NTPSERVER1)
AC_SUBST(EXTERNAL_NTPSERVER2)
AC_SUBST(EXTERNAL_NTPSERVER3)
AC_SUBST(EXTERNAL_NTPSERVER4)
AC_SUBST(NTPDRIFTFILE)
AC_SUBST(TBLOGFACIL)
AC_SUBST(TESTBED_NETWORK)
AC_SUBST(EXTERNAL_TESTBED_NETWORK)
AC_SUBST(TESTBED_NETMASK)
AC_SUBST(EXTERNAL_TESTBED_NETMASK)
AC_SUBST(BOSSNODE_IP)
AC_SUBST(EXTERNAL_BOSSNODE_IP)
AC_SUBST(USERNODE_IP)
AC_SUBST(EXTERNAL_USERNODE_IP)
AC_SUBST(FSNODE_IP)
AC_SUBST(EXTERNAL_FSNODE_IP)
AC_SUBST(CONTROL_ROUTER_IP)
AC_SUBST(CONTROL_NETWORK)
AC_SUBST(CONTROL_NETMASK)
AC_SUBST(PRIVATE_NETWORK)
AC_SUBST(PRIVATE_ROUTER)
AC_SUBST(PRIVATE_NETMASK)
AC_SUBST(PUBLIC_NETWORK)
AC_SUBST(PUBLIC_ROUTER)
AC_SUBST(PUBLIC_NETMASK)
AC_SUBST(MANAGEMENT_NETWORK)
AC_SUBST(MANAGEMENT_NETMASK)
AC_SUBST(MANAGEMENT_ROUTER)
AC_SUBST(VIRTNODE_NETWORK)
AC_SUBST(VIRTNODE_NETMASK)
AC_SUBST(DHCPD_DYNRANGE)
AC_SUBST(DHCPD_EXTRAIFS)
AC_SUBST(DHCPD_CONTROLNET_DECL)
AC_SUBST(NAMED_FORWARDERS)
AC_SUBST(NAMED_ALSONOTIFY)
AC_SUBST(SSLCERT_COUNTRY)
AC_SUBST(SSLCERT_STATE)
AC_SUBST(SSLCERT_LOCALITY)
AC_SUBST(SSLCERT_ORGNAME)
AC_SUBST(FRISEBEEMCASTADDR)
AC_SUBST(FRISEBEEMCASTPORT)
AC_SUBST(FRISEBEENUMPORTS)
AC_SUBST(WINSUPPORT)
AC_SUBST(NSVERIFY)
AC_SUBST(CVSSUPPORT)
AC_SUBST(TRACSUPPORT)
AC_SUBST(CHATSUPPORT)
AC_SUBST(STAMPS)
AC_SUBST(ARCHIVESUPPORT)
AC_SUBST(MIN_UNIX_UID)
AC_SUBST(MIN_UNIX_GID)
AC_SUBST(DELAYTHRESH)
AC_SUBST(PELABSUPPORT)
AC_SUBST(MOBILESUPPORT)
AC_SUBST(ELVIN_COMPAT)
AC_SUBST(ISOLATEADMINS)
AC_SUBST(DYNAMICROOTPASSWORDS)
AC_SUBST(TPM)
AC_SUBST(REMOTEWIKIDOCS)
AC_SUBST(POWDER_DEADMAN)
AC_SUBST(PROTOGENI_SUPPORT)
AC_SUBST(PROTOGENI_NOPORTALEXPIRE)
AC_SUBST(PROTOGENI_PORTALONLY)
AC_SUBST(PROTOGENI_WEBSITE)
AC_SUBST(PROTOGENI_ISCLEARINGHOUSE)
AC_SUBST(PROTOGENI_EMAIL)
AC_SUBST(PROTOGENI_DOMAIN)
AC_SUBST(PROTOGENI_RPCPORT)
AC_SUBST(PROTOGENI_RPCNAME)
AC_SUBST(PROTOGENI_LOCALUSER)
AC_SUBST(PROTOGENI_PGERRORS)
AC_SUBST(PROTOGENI_MAXSERVERLOAD)
AC_SUBST(PROTOGENI_GENIWEBLOGIN)
AC_SUBST(PROTOGENI_HOLDINGPROJECT)
AC_SUBST(PROTOGENI_NONFSMOUNTS)
AC_SUBST(GENI_PUBRPCPORT)
AC_SUBST(PROTOGENI_URL)
AC_SUBST(PROTOGENI_GENIRACK)
AC_SUBST(PROTOGENI_NICKNAME)
AC_SUBST(STANDALONE_CLEARINGHOUSE)
AC_SUBST(CONFIG_TARGETSYS)
AC_SUBST(TARGETSYS_TARGET)
AC_SUBST(GMAP_API_KEY)
AC_SUBST(NODE_USAGE_SUPPORT)
AC_SUBST(NOSTACKMIB)
AC_SUBST(EXP_VIS_SUPPORT)
AC_SUBST(NOSHAREDFS)
AC_SUBST(IMPORT_TMPDIR)
AC_SUBST(SELFLOADER_DATA)
AC_SUBST(TBUSEDBI)
AC_SUBST(BIGDB)
AC_SUBST(NEEDMCQUERIER)
AC_SUBST(OPSVM_ENABLE)
AC_SUBST(OPSVM_MOUNTPOINT)
AC_SUBST(CLASSICWEB_OVERRIDE)
AC_SUBST(PORTAL_ENABLE)
AC_SUBST(PEER_ENABLE)
AC_SUBST(PEER_ISPRIMARY)
AC_SUBST(CLOUDLAB_FEDERATED)
AC_SUBST(LINUX_FSNODE)
AC_SUBST(VPUBADDR_BASE)
AC_SUBST(VPUBADDR_BITLEN)
AC_SUBST(WINDOWS_ORGNAME)
AC_SUBST(WINDOWS_OWNER)
AC_SUBST(WINDOWS_TIMEZONE)
AC_SUBST(WINDOWS_KEY_7PRO_X86)
AC_SUBST(FIREWALL_BOSS)
AC_SUBST(FIREWALL_OPS)
AC_SUBST(FIREWALL_BOSS_LOCALRULETMPL)
AC_SUBST(FIREWALL_OPS_LOCALRULETMPL)
AC_SUBST(SPEWFROMOPS)
AC_SUBST(NOSITECHECKIN)
AC_SUBST(EC2META_ENABLE)
AC_SUBST(BROWSER_CONSOLE_ENABLE)
AC_SUBST(BROWSER_CONSOLE_PROXIED)
AC_SUBST(BROWSER_CONSOLE_WEBSSH)
AC_SUBST(IPV6_ENABLED)
AC_SUBST(IPV6_SUBNET_PREFIX)
AC_SUBST(NFSMAPTOUSER)
AC_SUBST(IMAGEPROVENANCE)
AC_SUBST(IMAGEDIRECTORIES)
AC_SUBST(IMAGEDELTAS)
AC_SUBST(IMAGEUPLOADTOFS)
AC_SUBST(PROFILEVERSIONS)
AC_SUBST(NOVIRTNFSMOUNTS)
AC_SUBST(WITHZFS)
AC_SUBST(ZFS_ROOT)
AC_SUBST(ZFS_QUOTA_USER)
AC_SUBST(ZFS_QUOTA_PROJECT)
AC_SUBST(ZFS_QUOTA_GROUP)
AC_SUBST(ZFS_QUOTA_USER_X)
AC_SUBST(ZFS_QUOTA_PROJECT_X)
AC_SUBST(ZFS_QUOTA_GROUP_X)
AC_SUBST(ZFS_NOEXPORT)
AC_SUBST(ZFS_NONFS_DIR)
AC_SUBST(INCREMENTAL_MOUNTD)
AC_SUBST(WITHAMD)
AC_SUBST(AMD_ROOT)
AC_SUBST(NFSMFS_ROOT)
AC_SUBST(BS_IQN_PREFIX)
AC_SUBST(ATTENUATOR)
AC_SUBST(CLUSTER_PORTAL)
AC_SUBST(CLUSTER_PUBSUBD_SSLPORT)
AC_SUBST(CLUSTER_PUBSUBD_ALTPORT)
AC_SUBST(EXPIRE_PASSWORDS)
AC_SUBST(SDCOLLECTD_DOSTATS)
AC_SUBST(SDCOLLECTD_USE_RRDTOOL)
AC_SUBST(BOOTINFO_EVENTS)
AC_SUBST(REPORTBOOT_ENABLED)
AC_SUBST(REPORTBOOT_FLAGS)
AC_SUBST(UI_DISABLE_DATASETS)
AC_SUBST(UI_DISABLE_RESERVATIONS)
AC_SUBST(UI_EXTERNAL_ACCOUNTS)
AC_SUBST(POWDER_RFMONITOR)
AC_SUBST(POWDER_RFMONITOR_HOST)
AC_SUBST(POWDER_NICKNAME)
AC_SUBST(POWDER_WBSTORE)
AC_SUBST(POWDER_BUS_P0WER_VERSION);
AC_SUBST(DISABLE_RESERVATION_EMAIL)
AC_SUBST(MAILERNODE)

#
# Offer both versions of the email addresses that have the @ escaped
# for perl (the default), and that don't
#
AC_SUBST(TBOPSEMAIL)
AC_SUBST(TBOPSEMAIL_NOSLASH)
AC_SUBST(TBROBOCOPSEMAIL)
AC_SUBST(TBROBOCOPSEMAIL_NOSLASH)
AC_SUBST(TBLOGSEMAIL)
AC_SUBST(TBLOGSEMAIL_NOSLASH)
AC_SUBST(TBWWWEMAIL)
AC_SUBST(TBWWWEMAIL_NOSLASH)
AC_SUBST(TBAPPROVALEMAIL)
AC_SUBST(TBAPPROVALEMAIL_NOSLASH)
AC_SUBST(TBAUDITEMAIL)
AC_SUBST(TBAUDITEMAIL_NOSLASH)
AC_SUBST(TBSTATEDEMAIL)
AC_SUBST(TBSTATEDEMAIL_NOSLASH)
AC_SUBST(TBTESTSUITEEMAIL)
AC_SUBST(TBTESTSUITEEMAIL_NOSLASH)
AC_SUBST(TBAUTOMAILEMAIL)
AC_SUBST(TBAUTOMAILEMAIL_NOSLASH)
AC_SUBST(TBACTIVEARCHIVE)
AC_SUBST(TBACTIVEARCHIVE_NOSLASH)
AC_SUBST(TBUSERSARCHIVE)
AC_SUBST(TBUSERSARCHIVE_NOSLASH)
AC_SUBST(TBERRORSEMAIL)
AC_SUBST(TBERRORSEMAIL_NOSLASH)

#
# For snmpit support of Arista switch.
#
AC_SUBST(ARISTA_SWITCH_XMLRPCPORT)

#
# Defaults for for above variables.
#
TBERRORLOGDBNAME="errorlog"
TBADMINGROUP="flux"
CLIENT_ETCDIR="/etc/emulab"
CLIENT_BINDIR="/usr/local/etc/emulab"
CLIENT_VARDIR="/var/emulab"
CLIENT_MANDIR="/usr/local/man"
TBSECURECOOKIES=1
TBMAINSITE=0
TBUSEDBI=0
BIGDB=0
FANCYBANNER=0
VIRTNODE_NETWORK=172.16.0.0
VIRTNODE_NETMASK=255.240.0.0
JAILIPBASE=$VIRTNODE_NETWORK
JAILIPMASK=$VIRTNODE_NETMASK
IPBASE=10
SFSSUPPORT=0
ELABINELAB=0
ELABINELAB_MAILTARGET=""
OUTERBOSS_NODENAME=""
OUTERBOSS_XMLRPCPORT=3069
OUTERBOSS_SSLCERTNAME="/etc/outer_emulab.pem"
SUBBOSS_SSLCERTNAME="/etc/subboss.pem"
PLABSUPPORT=0
PUBSUPPORT=0
WIKISUPPORT=0
BUGDBSUPPORT=0
OPSDBSUPPORT=0
MAILMANSUPPORT=0
PROJECTMAILLISTS=0
WINSUPPORT=0
NSVERIFY=1
CVSSUPPORT=0
TRACSUPPORT=0
CHATSUPPORT=0
STAMPS=0
ARCHIVESUPPORT=0
NFSTRACESUPPORT=0
TBLOGFACIL="local5"
BOSSEVENTPORT=16505
NTPSERVER="ops"
EXTERNAL_NTPSERVER1="0.pool.ntp.org"
EXTERNAL_NTPSERVER2="1.pool.ntp.org"
EXTERNAL_NTPSERVER3="2.pool.ntp.org"
EXTERNAL_NTPSERVER4="3.pool.ntp.org"
NTPDRIFTFILE="/var/db/ntp.drift"
UNIFIED_BOSS_AND_OPS=0
DISABLE_NAMED_INSTALL=0
DISABLE_DHCPD_INSTALL=0
DISABLE_NAMED_SETUP=0
DISABLE_EXPORTS_SETUP=0
DISABLE_FSNODE_CHFLAGS=0
FRISEBEEMCASTADDR="234.5.6"
FRISEBEEMCASTPORT=3564
FRISEBEENUMPORTS=0
MIN_UNIX_UID=10000
MIN_UNIX_GID=6000
DELAYTHRESH=2
PELABSUPPORT=0
MOBILESUPPORT=0
ELVIN_COMPAT=0
ISOLATEADMINS=1
DYNAMICROOTPASSWORDS=1
TPM=0
REMOTEWIKIDOCS=1
POWDER_DEADMAN=0
PROTOGENI_SUPPORT=0
PROTOGENI_NOPORTALEXPIRE=0
PROTOGENI_PORTALONLY=0
PROTOGENI_ISCLEARINGHOUSE=0
PROTOGENI_EMAIL="geni-dev-utah@flux.utah.edu"
PROTOGENI_WEBSITE="www.emulab.net"
PROTOGENI_DOMAIN="unknown"
PROTOGENI_RPCPORT=12369
PROTOGENI_RPCNAME=""
PROTOGENI_LOCALUSER=0
PROTOGENI_PGERRORS="protogeni-errors@flux.utah.edu"
PROTOGENI_GENIWEBLOGIN=0
PROTOGENI_HOLDINGPROJECT=""
PROTOGENI_MAXSERVERLOAD=12
PROTOGENI_NONFSMOUNTS=0
GENI_PUBRPCPORT=12370
PROTOGENI_GENIRACK=0
CONFIG_TARGETSYS=0
TARGETSYS_TARGET=""
PROTOGENI_NICKNAME="unknown"
STANDALONE_CLEARINGHOUSE=0
NODE_USAGE_SUPPORT=0
EXP_VIS_SUPPORT=0
NOSTACKMIB=0
NOSHAREDFS=0
IMPORT_TMPDIR="/q"
NFSRACY=1
SELFLOADER_DATA=""
NEEDMCQUERIER=0
OPSVM_ENABLE=0
OPSVM_MOUNTPOINT="/ops"
OURTIMEZONE="America/Denver"
NODECONSOLE="sio"
MFSVERSION=""
CLASSICWEB_OVERRIDE=0
PORTAL_ENABLE=0
PEER_ENABLE=0
PEER_ISPRIMARY=0
CLOUDLAB_FEDERATED=0
LINUX_FSNODE=0
DHCPD_EXTRAIFS=""
VPUBADDR_BASE="none"
VPUBADDR_BITLEN="none"
ARISTA_SWITCH_XMLRPCPORT=80
FIREWALL_BOSS=0
FIREWALL_OPS=0
FIREWALL_BOSS_LOCALRULETMPL=""
FIREWALL_OPS_LOCALRULETMPL=""
SPEWFROMOPS=0
NOSITECHECKIN=0
EC2META_ENABLE=0
BROWSER_CONSOLE_ENABLE=0
BROWSER_CONSOLE_PROXIED=0
BROWSER_CONSOLE_WEBSSH=0
IPV6_ENABLED=0
IPV6_SUBNET_PREFIX=""
MANAGEMENT_NETWORK="10.249.249.0"
MANAGEMENT_NETMASK="255.255.255.0"
MANAGEMENT_ROUTER="10.249.249.253"
NFSMAPTOUSER="root"
IMAGEPROVENANCE=0
IMAGEDIRECTORIES=0
IMAGEDELTAS=0
IMAGEUPLOADTOFS=0
PROFILEVERSIONS=0
NOVIRTNFSMOUNTS=0
WITHZFS=0
ZFS_ROOT=z
ZFS_QUOTA_USER="1G"
ZFS_QUOTA_PROJECT="100G"
ZFS_QUOTA_GROUP="10G"
ZFS_QUOTA_USER_X="1.0"
ZFS_QUOTA_PROJECT_X="1.0"
ZFS_QUOTA_GROUP_X="1.0"
ZFS_NOEXPORT=0
ZFS_NONFS_DIR=""
INCREMENTAL_MOUNTD=0
WITHAMD=0
AMD_ROOT=/.amd_mnt/ops
NFSMFS_ROOT=""
BS_IQN_PREFIX=iqn.2000-10.net.emulab
ATTENUATOR=""
CLUSTER_PORTAL=""
CLUSTER_PUBSUBD_ALTPORT=""
CLUSTER_PUBSUBD_SSLPORT=""
EXPIRE_PASSWORDS=1
SDCOLLECTD_DOSTATS=0
SDCOLLECTD_USE_RRDTOOL=0
BOOTINFO_EVENTS=1
REPORTBOOT_ENABLED=0
REPORTBOOT_FLAGS=""
UI_DISABLE_DATASETS=0
UI_DISABLE_RESERVATIONS=0
UI_EXTERNAL_ACCOUNTS=0
POWDER_RFMONITOR=0
POWDER_RFMONITOR_HOST="0.0.0.0"
POWDER_WBSTORE=0
POWDER_NICKNAME=""
POWDER_BUS_P0WER_VERSION=0
DISABLE_RESERVATION_EMAIL=0
MAILERNODE="ops"

#
# XXX You really don't want to change these!
# They are ingrained and who knows what might break if you change them.
#
USERSROOT_DIR="/users"
PROJROOT_DIR="/proj"
GROUPSROOT_DIR="/groups"
SHAREROOT_DIR="/share"
SCRATCHROOT_DIR=""

#
# Flag as full Emulab build (for clientside). 
#
WITH_EMULAB=1
AC_SUBST(WITH_EMULAB)

#
# Okay, I know this is improper usage of --with. Too bad.
#
AC_ARG_WITH(TBDEFS,
[  --with-TBDEFS=name	Specify definitions file (defs-default default)],
[
    if test "$withval" = "yes"; then
	AC_MSG_ERROR([Invalid TBDEFS - Must specify the value])
    fi
    TBDEFS="$withval"
    TBPATH=`dirname $withval`
],[
    AC_MSG_ERROR(
	[The required --with-TBDEFS= argument was not given.
The value of --with-TBDEFS= must be the path to your Emulab defs file.
Copy and modify the defs-example file for your Emulab installation.
defs-default has values for Utah, including client-side image compilations.])
])

if test -f $TBDEFS; then
    #
    # Remove the comments and newlines.  Really, that's what it does.
    #
    OLDPATH=$PATH
    PATH="$TBPATH:$PATH"
    . $TBDEFS
    PATH=$OLDPATH
else
	AC_MSG_ERROR([Definitions file $TBDEFS was not found.])
fi

# XXX this can optionally be set in the defs file
if test -n "$FSDIR_SCRATCH"; then
    SCRATCHROOT_DIR="/scratch"
fi

# Try to guess ProtoGENI nickname if it wasn't specified explicitly,
# for backward compatibility (nobody used to care what they were called)
if test x"$PROTOGENI_NICKNAME" = x"unknown"; then
    case $OURDOMAIN in
    *bbn.instageni.net) PROTOGENI_NICKNAME="gpo-ig";;
    *northwestern.edu) PROTOGENI_NICKNAME="northwestern-ig";;
    *lan.sdn.uky.edu) PROTOGENI_NICKNAME="uky-ig";;
    *kettering.edu) PROTOGENI_NICKNAME="kettering-ig";;
    *rnoc.gatech.edu) PROTOGENI_NICKNAME="gatech-ig";;
    *cs.princeton.edu) PROTOGENI_NICKNAME="princeton-ig";;
    *clemson.edu) PROTOGENI_NICKNAME="clemson-ig";;
    *ku.gpeni.net) PROTOGENI_NICKNAME="kansas-ig";;
    *nyu.edu) PROTOGENI_NICKNAME="nyu-ig";;
    *maxgigapop.net) PROTOGENI_NICKNAME="max-ig";;
    *nysernet.org) PROTOGENI_NICKNAME="nysernet-ig";;
    *sox.net) PROTOGENI_NICKNAME="sox-ig";;
    *illinois.edu) PROTOGENI_NICKNAME="illinois-ig";;
    *rnet.missouri.edu) PROTOGENI_NICKNAME="missouri-ig";;
    *wisc.edu) PROTOGENI_NICKNAME="wisconsin-ig";;
    *rutgers.edu) PROTOGENI_NICKNAME="rutgers-ig";;
    *stanford.edu) PROTOGENI_NICKNAME="stanford-ig";;
    *it.cornell.edu) PROTOGENI_NICKNAME="cornell-ig";;
    *case.edu) PROTOGENI_NICKNAME="cwru-ig";;
    *iu.edu) PROTOGENI_NICKNAME="moxi-ig";;
    *uchicago.edu) PROTOGENI_NICKNAME="uchicago-ig";;
    *metrodatacenter.com) PROTOGENI_NICKNAME="ohmetrodc-ig";;
    *nps.edu) PROTOGENI_NICKNAME="nps-ig";;
    *osu.edu) PROTOGENI_NICKNAME="osu-ig";;
    *umkc.edu) PROTOGENI_NICKNAME="umkc-ig";;
    *idre.ucla.edu) PROTOGENI_NICKNAME="ucla-ig";;
    *washington.edu) PROTOGENI_NICKNAME="uwashington-ig";;
    *rnet.missouri.edu) PROTOGENI_NICKNAME="missouri-ig";;
    *pks2.sdn.uky.edu) PROTOGENI_NICKNAME="ukypks2-ig";;
    *mcv.sdn.uky.edu) PROTOGENI_NICKNAME="ukymcv-ig";;
    *hawaii.edu) PROTOGENI_NICKNAME="hawaii-ig";;
    *colorado.edu) PROTOGENI_NICKNAME="colorado-ig";;
    *cenic.net) PROTOGENI_NICKNAME="cenic-ig";;
    *vt.edu) PROTOGENI_NICKNAME="vt-ig";;
    *vcu.instageni.net) PROTOGENI_NICKNAME="vcu-ig";;
    *utc.edu) PROTOGENI_NICKNAME="utc-ig";;
    *research.umich.edu) PROTOGENI_NICKNAME="umich-ig";;
    *ucsd.edu) PROTOGENI_NICKNAME="ucsd-ig";;
    *uvm.edu) PROTOGENI_NICKNAME="uvm-ig";;
    *utdallas.edu) PROTOGENI_NICKNAME="utdallas-ig";;
    *odu.edu) PROTOGENI_NICKNAME="odu-ig";;
    *louisiana.edu) PROTOGENI_NICKNAME="ullafayette-ig";;
    *stitch.geniracks.net) PROTOGENI_NICKNAME="utah-stitch";;
    esac
fi

#
# These must come after the "eval" above, since the variables are not
# defined until the defs file is taken in.
#
# Be sure to add to config.h.in!
#
if test x"$prefix" = x"NONE"; then
    AC_DEFINE_UNQUOTED(TBROOT, "/usr/testbed", [FS base for Emulab files])
else
    AC_DEFINE_UNQUOTED(TBROOT, "$prefix", [FS base for Emulab files])
fi
AC_DEFINE_UNQUOTED(TBMAINSITE, $TBMAINSITE, [The Mothership])
AC_DEFINE_UNQUOTED(TBDBNAME, "$TBDBNAME", [Emulab DB name])
AC_DEFINE_UNQUOTED(TBERRORLOGDBNAME, "$TBERRORLOGDBNAME", [Emulab errorlog DB])
AC_DEFINE_UNQUOTED(TBADMINGROUP, "$TBADMINGROUP", [Unix group of admin user])
AC_DEFINE_UNQUOTED(IPBASE, "$IPBASE", [Base of IPv4 space used for experiments])
AC_DEFINE_UNQUOTED(JAILIPBASE, "$JAILIPBASE", [Base of IPv4 space used for VMs])
AC_DEFINE_UNQUOTED(JAILIPMASK, "$JAILIPMASK", [Netmask for JAILIPBASE])
AC_DEFINE_UNQUOTED(BOSSNODE, "$BOSSNODE", [DNS name of boss node])
AC_DEFINE_UNQUOTED(BOSSNODE_IP, "$BOSSNODE_IP", [IPv4 address of boss node to be used by nodes])
AC_DEFINE_UNQUOTED(EXTERNAL_BOSSNODE_IP, "$EXTERNAL_BOSSNODE_IP", [IPv4 address of boss used from outside])
AC_DEFINE_UNQUOTED(USERNODE, "$USERNODE", [DNS name of ops node])
AC_DEFINE_UNQUOTED(USERNODE_IP, "$USERNODE_IP", [IPv4 address of ops node to be used by nodes])
AC_DEFINE_UNQUOTED(EXTERNAL_USERNODE_IP, "$EXTERNAL_USERNODE_IP", [IPv4 address of ops used from outside])
AC_DEFINE_UNQUOTED(FSNODE, "$FSNODE", [DNS name of fs node])
if test -n "$FSNODE_IP"; then
	AC_DEFINE_UNQUOTED(FSNODE_IP, "$FSNODE_IP", [IPv4 address of fs node to be used by nodes])
elif test "$USERNODE" = "$FSNODE"; then
	AC_DEFINE_UNQUOTED(FSNODE_IP, "$USERNODE_IP", [IPv4 address of fs node to be used by nodes])
elif test "$BOSSNODE" = "$FSNODE"; then
	AC_DEFINE_UNQUOTED(FSNODE_IP, "$BOSSNODE_IP", [IPv4 address of fs node to be used by nodes])
fi
AC_DEFINE_UNQUOTED(CONTROL_ROUTER_IP, "$CONTROL_ROUTER_IP", [IPv4 address of router to be used by nodes])
AC_DEFINE_UNQUOTED(CONTROL_NETWORK, "$CONTROL_NETWORK", [IPv4 node control network])
AC_DEFINE_UNQUOTED(CONTROL_NETMASK, "$CONTROL_NETMASK", [IPv4 node control network mask])
AC_DEFINE_UNQUOTED(USERSROOT_DIR, "$USERSROOT_DIR", [Root of 'users' filesystem])
AC_DEFINE_UNQUOTED(PROJROOT_DIR, "$PROJROOT_DIR", [Root of 'proj' filesystem])
AC_DEFINE_UNQUOTED(GROUPSROOT_DIR, "$GROUPSROOT_DIR", [Root of 'groups' filesystem])
AC_DEFINE_UNQUOTED(SCRATCHROOT_DIR, "$SCRATCHROOT_DIR", [Root of 'scratch' filesystem])
AC_DEFINE_UNQUOTED(SHAREROOT_DIR, "$SHAREROOT_DIR", [Root of 'share' filesystem])
AC_DEFINE_UNQUOTED(FSDIR_PROJ, "$FSDIR_PROJ", [Mount point of 'proj' filesystem on fs node])
AC_DEFINE_UNQUOTED(FSDIR_GROUPS, "$FSDIR_GROUPS", [Mount point of 'groups' filesystem on fs node])
AC_DEFINE_UNQUOTED(FSDIR_USERS, "$FSDIR_USERS", [Mount point of 'users' filesystem on fs node])
if test -n "$FSDIR_SHARE"; then
    AC_DEFINE_UNQUOTED(FSDIR_SHARE, "$FSDIR_SHARE", [Mount point of 'share' filesystem on fs node])
fi
if test -n "$FSDIR_SCRATCH"; then
    AC_DEFINE_UNQUOTED(FSDIR_SCRATCH, "$FSDIR_SCRATCH", [Mount point of 'scratch' filesystem on fs node])
fi
AC_DEFINE_UNQUOTED(BOSSEVENTPORT, "$BOSSEVENTPORT", [IPv4 address of pubsub server on boss])
AC_DEFINE_UNQUOTED(FRISEBEEMCASTADDR, "$FRISEBEEMCASTADDR", [Base IPv4 multicast address for disk imaging])
AC_DEFINE_UNQUOTED(FRISEBEEMCASTPORT, "$FRISEBEEMCASTPORT", [Base IPv4 port for disk imaging])
AC_DEFINE_UNQUOTED(FRISEBEENUMPORTS, "$FRISEBEENUMPORTS", [Number of IPv4 ports for disk imaging])

AC_DEFINE_UNQUOTED(NTPSERVER, "$NTPSERVER", [NTP server for nodes])
AC_DEFINE_UNQUOTED(EXTERNAL_NTPSERVER1, "$EXTERNAL_NTPSERVER1", [External NTP server for NTP node])
AC_DEFINE_UNQUOTED(EXTERNAL_NTPSERVER2, "$EXTERNAL_NTPSERVER2", [External NTP server for NTP node])
AC_DEFINE_UNQUOTED(EXTERNAL_NTPSERVER3, "$EXTERNAL_NTPSERVER3", [External NTP server for NTP node])
AC_DEFINE_UNQUOTED(EXTERNAL_NTPSERVER4, "$EXTERNAL_NTPSERVER4", [External NTP server for NTP node])
AC_DEFINE_UNQUOTED(NTPDRIFTFILE, "$NTPDRIFTFILE", [Location of NTP driftfile])

AC_DEFINE_UNQUOTED(MANAGEMENT_NETWORK, "$MANAGEMENT_NETWORK", [IPv4 node mangagement network])
AC_DEFINE_UNQUOTED(MANAGEMENT_NETMASK, "$MANAGEMENT_NETMASK", [IPv4 node management netmask])
AC_DEFINE_UNQUOTED(MANAGEMENT_ROUTER, "$MANAGEMENT_ROUTER", [IPv4 node management default GW])

if test $OPSDBSUPPORT -eq 1; then
    AC_DEFINE_UNQUOTED(OPSDBSUPPORT, 1, [Obsolete])
fi

if test $ELVIN_COMPAT -eq 1; then
    AC_DEFINE_UNQUOTED(ELVIN_COMPAT, 1, [Obsolete])
fi

if test $ELABINELAB -eq 1; then
    AC_DEFINE_UNQUOTED(ELABINELAB, 1, [For an Emulab-in-Emulab configuration])
fi

if test $ISOLATEADMINS -eq 1; then
    AC_DEFINE_UNQUOTED(ISOLATEADMINS, 1, [Do not allow admins and non-admins in same project])
fi
if test $DYNAMICROOTPASSWORDS -eq 1; then
    AC_DEFINE_UNQUOTED(DYNAMICROOTPASSWORDS, 1, [Per-node root passwords])
fi
if test $TPM -eq 1; then
    AC_DEFINE_UNQUOTED(TPM, 1, [Something about TPM])
fi
if test $NOSHAREDFS -eq 1; then
    AC_DEFINE_UNQUOTED(NOSHAREDFS, 1, [Do not allow NFS-shared filesystems])
fi
if test $NFSRACY -eq 1; then
    AC_DEFINE_UNQUOTED(NFSRACY, 1, [NFS server has race])
fi
if test $OPSVM_ENABLE -eq 1; then
    AC_DEFINE_UNQUOTED(OPSVM_ENABLE, 1, [ops node is a VM])
    AC_DEFINE_UNQUOTED(OPSVM_MOUNTPOINT, $OPSVM_MOUNTPOINT, [mount point on boss for ops VM FSes])
fi
if test $SPEWFROMOPS -eq 1; then
    AC_DEFINE_UNQUOTED(SPEWFROMOPS, 1, [Server rpm/tarballs from ops rather than boss])
fi
if test $PROTOGENI_SUPPORT -eq 1; then
    AC_DEFINE_UNQUOTED(PROTOGENI_SUPPORT, 1, [Support Protogeni])
fi
if test $PROTOGENI_GENIRACK -eq 1; then
    AC_DEFINE_UNQUOTED(PROTOGENI_GENIRACK, 1, [Support Protogeni rack])
fi
if test $IMAGEPROVENANCE -eq 1; then
    AC_DEFINE_UNQUOTED(IMAGEPROVENANCE, 1, [Support image versioning])
fi
if test $IMAGEDELTAS -eq 1; then
    AC_DEFINE_UNQUOTED(IMAGEDELTAS, 1, [Support imagezip delta images])
fi
if test $IMAGEUPLOADTOFS -eq 1; then
    AC_DEFINE_UNQUOTED(IMAGEUPLOADTOFS, 1, [Support image uploading to fs node])
fi
if test $NOVIRTNFSMOUNTS -eq 1; then
    AC_DEFINE_UNQUOTED(NOVIRTNFSMOUNTS, 1, [Do not use NFS mounts on virtual nodes])
fi
if test $WITHZFS -eq 1; then
    AC_DEFINE_UNQUOTED(WITHZFS, 1, [Use ZFS on FS node for shared filesystems])
fi
if test $WITHAMD -eq 1; then
    AC_DEFINE_UNQUOTED(WITHAMD, 1, [Run AMD on boss node to handle shared FS mounts])
    AC_DEFINE_UNQUOTED(AMD_ROOT, "$AMD_ROOT", [Actual FS mount directory for AMD])
fi
if test $PROTOGENI_LOCALUSER -eq 1; then
    AC_DEFINE_UNQUOTED(PROTOGENI_LOCALUSER, 1, [Map geni users to local users,projects,groups])
fi
AC_DEFINE_UNQUOTED(IMPORT_TMPDIR, "$IMPORT_TMPDIR", [Directory to use for imported images])

LOG_TESTBED=`echo "LOG_$TBLOGFACIL" | tr a-z A-Z`
AC_DEFINE_UNQUOTED(LOG_TESTBED, $LOG_TESTBED, [Syslog log facility for Emulab daemons])
AC_SUBST(LOG_TESTBED)

#
# If the private network is different then the control network, we need
# an extra subnet decl for it in dhcpd.conf.template. This is enormously
# crude and simplistic, but works for the local case!
#
if test "$PRIVATE_NETWORK" != "$CONTROL_NETWORK"; then
    DHCPD_CONTROLNET_DECL="subnet $PRIVATE_NETWORK netmask $PRIVATE_NETMASK {}"
fi

#
# The email addresses need to be be munged for perl scripts. But,
# php needs them un-escaped
#
TBOPSEMAIL_NOSLASH="$TBOPSEMAIL"
TBOPSEMAIL="`echo $TBOPSEMAIL | sed -e 's/@/\\\@/'`"
TBROBOCOPSEMAIL_NOSLASH="$TBROBOCOPSEMAIL"
TBROBOCOPSEMAIL="`echo $TBROBOCOPSEMAIL | sed -e 's/@/\\\@/'`"
TBLOGSEMAIL_NOSLASH="$TBLOGSEMAIL"
TBLOGSEMAIL="`echo $TBLOGSEMAIL | sed -e 's/@/\\\@/'`"
TBAUDITEMAIL_NOSLASH="$TBAUDITEMAIL"
TBAUDITEMAIL="`echo $TBAUDITEMAIL | sed -e 's/@/\\\@/'`"
TBWWWEMAIL_NOSLASH="$TBWWWEMAIL"
TBWWWEMAIL="`echo $TBWWWEMAIL | sed -e 's/@/\\\@/'`"
TBAPPROVALEMAIL_NOSLASH="$TBAPPROVALEMAIL"
TBAPPROVALEMAIL="`echo $TBAPPROVALEMAIL | sed -e 's/@/\\\@/'`"
TBSTATEDEMAIL_NOSLASH="$TBSTATEDEMAIL_NOSLASH"
TBSTATEDEMAIL="`echo $TBSTATEDEMAIL | sed -e 's/@/\\\@/'`"
TBTESTSUITEEMAIL_NOSLASH="$TBTESTSUITEEMAIL_NOSLASH"
TBTESTSUITEEMAIL="`echo $TBTESTSUITEEMAIL | sed -e 's/@/\\\@/'`"

if test -n "$TBAUTOMAILEMAIL"; then
    TBAUTOMAILEMAIL_NOSLASH="$TBAUTOMAILEMAIL"
    TBAUTOMAILEMAIL="`echo $TBAUTOMAILEMAIL | sed -e 's/@/\\\@/'`"
else
    TBAUTOMAILEMAIL_NOSLASH="$TBLOGSEMAIL_NOSLASH"
    TBAUTOMAILEMAIL="$TBLOGSEMAIL"
fi
if test -n "$TBACTIVEARCHIVE"; then
    TBACTIVEARCHIVE_NOSLASH="$TBACTIVEARCHIVE"
    TBACTIVEARCHIVE="`echo $TBACTIVEARCHIVE | sed -e 's/@/\\\@/'`"
else
    TBACTIVEARCHIVE_NOSLASH="$TBOPSEMAIL_NOSLASH"
    TBACTIVEARCHIVE="$TBOPSEMAIL"
fi
if test -n "$TBUSERSARCHIVE"; then
    TBUSERSARCHIVE_NOSLASH="$TBUSERSARCHIVE"
    TBUSERSARCHIVE="`echo $TBUSERSARCHIVE | sed -e 's/@/\\\@/'`"
else
    TBUSERSARCHIVE_NOSLASH="$TBOPSEMAIL_NOSLASH"
    TBUSERSARCHIVE="$TBOPSEMAIL"
fi
if test -n "$TBERRORSEMAIL"; then
    TBERRORSEMAIL_NOSLASH="$TBERRORSEMAIL"
    TBERRORSEMAIL="`echo $TBERRORSEMAIL | sed -e 's/@/\\\@/'`"
else
    TBERRORSEMAIL_NOSLASH="$TBOPSEMAIL_NOSLASH"
    TBERRORSEMAIL="$TBOPSEMAIL"
fi
if test -n "$PROTOGENI_EMAIL"; then
    PROTOGENI_EMAIL="`echo $PROTOGENI_EMAIL | sed -e 's/@/\\\@/'`"
fi
if test -n "ELABINELAB_MAILTARGET"; then
    ELABINELAB_MAILTARGET="`echo $ELABINELAB | sed -e 's/@/\\\@/'`"
fi
PROTOGENI_PGERRORS="`echo $PROTOGENI_PGERRORS | sed -e 's/@/\\\@/'`"

# Default OURDOMAIN to the domain name of the boss node
# This is gross beyond all description - autoconf changes m4's quote characters
# to '[' and ']', which prevents them from working in the sed expression below.
# So, we temporarily change them to something else then change them back.
# Note: In newer versions of autoconf, this can be done with 'quadrigraphs'
changequote(START, END)dnl
if test -z "$OURDOMAIN"; then
    OURDOMAIN="`echo $BOSSNODE | sed -E -e 's/^[a-zA-Z0-9\-]+\.//'`"
fi
changequote([, ])dnl
AC_DEFINE_UNQUOTED(OURDOMAIN, "$OURDOMAIN", [Domain name of Emulab site])

if test -z "$EXTERNAL_TESTBED_NETWORK"; then
    EXTERNAL_TESTBED_NETWORK=$TESTBED_NETWORK
fi
if test -z "$EXTERNAL_TESTBED_NETMASK"; then
    EXTERNAL_TESTBED_NETMASK=$TESTBED_NETMASK
fi
if test -z "$EXTERNAL_BOSSNODE_IP"; then
    EXTERNAL_BOSSNODE_IP=$BOSSNODE_IP
fi
if test -z "$EXTERNAL_USERNODE_IP"; then
    EXTERNAL_USERNODE_IP=$USERNODE_IP
fi
if test -z "$FSNODE_IP"; then
    FSNODE_IP=$USERNODE_IP
fi
if test -z "$EXTERNAL_FSNODE_IP"; then
    EXTERNAL_FSNODE_IP=$FSNODE_IP
fi
if test -z "$TBAUTHDOMAIN"; then
    TBAUTHDOMAIN=".$OURDOMAIN"
fi
if test -z "$TBAUTHTIMEOUT"; then
    TBAUTHTIMEOUT="86400"
fi
if test -z "$WWW"; then
    WWW="$WWWHOST"
fi
if test -z "$TBBASE"; then
    TBBASE="https://$WWW"
fi
if test -z "$TBDOCBASE"; then
    TBDOCBASE="http://$WWW"
fi
if test -z "$TBWWW"; then
    TBWWW="<$TBBASE/>"
fi
AC_DEFINE_UNQUOTED(TBBASE, "$TBBASE", [Base URL for Emulab files])

if test -z "$THISHOMEBASE"; then
    THISHOMEBASE="Emulab.Net"
fi
if test -z "$EVENTSERVER"; then
    EVENTSERVER="event-server"
fi
AC_DEFINE_UNQUOTED(EVENTSERVER, "$EVENTSERVER", [Emulab event server node])
AC_DEFINE_UNQUOTED(BS_IQN_PREFIX, "$BS_IQN_PREFIX", [IQN prefix for blockstores])

#
# Perl SelfLoader
# XXX this is a hack which enables us to disable it on versions of perl
# where there are problems with taint checking in the SelfLoader module.
#
AC_DEFINE_UNQUOTED(SELFLOADER_DATA, "$SELFLOADER_DATA", [Need perl SelfLoader hack])

#
# LEDA library path
#
AC_ARG_WITH(LEDA,
[  --with-LEDA		Specify LEDA path (/usr/testbed default)],
[
    if test "$withval" = "yes"; then
        LEDA="$ac_default_prefix/LEDA/LEDA-4.0"
    else
        LEDA="$withval"
    fi
],[
    if test -d "$ac_default_prefix/LEDA/LEDA-4.0"; then
        LEDA="$ac_default_prefix/LEDA/LEDA-4.0"
    else
        LEDA=""
    fi
])
AC_SUBST(LEDA)

#
# Override LEDA with assign binary.
#
AC_ARG_WITH(assignbinary,
[  --with-assignbinary	Specify assign binary (overrides LEDA, default on)],
[
    if test "$withval" = "yes"; then
        ASSIGN="assign.bin"
        LEDA=""
    else
        ASSIGN="$withval"
        LEDA=""
    fi
],[
    if test "$LEDA" = ""; then
        ASSIGN="assign.bin"
    else
        ASSIGN=""
    fi
])
AC_SUBST(ASSIGN)

#
# Arguments to ssh to disable strict host key checking, etc
#
AC_ARG_WITH(ssh-args,
[  --with-ssh-args	Specify ssh arguments when running from testbed scripts ],
[
    SSH_ARGS="$withval"
],[
    SSH_ARGS="-q -o BatchMode=yes -o StrictHostKeyChecking=no"
])
AC_SUBST(SSH_ARGS)

#
# Path to install rc.d scripts in
#
AC_ARG_WITH(rcdir,
[  --with-rcdir		Specify path to install rc.d scripts (/usr/local/etc/rc.d default)],
[
    INSTALL_RCDIR="$with_rcdir"
],[
    INSTALL_RCDIR="/usr/local/etc/rc.d"
])
AC_SUBST(INSTALL_RCDIR)

#
# Path to install apache config files in
#
AC_ARG_WITH(apache-config-dir,
[  --with-apache-config	Specify path to install apache config files (/usr/local/etc/apache default)],
[
    INSTALL_APACHE_CONFIG="$withval"
],[
    foo=`/usr/local/sbin/httpd -V | grep SERVER_CONFIG_FILE | grep 'apache2'`
    if test "$foo" = ""; then
        INSTALL_APACHE_CONFIG="/usr/local/etc/apache"
	APACHE_VERSION="1.3"
	APACHE_START_COMMAND="/usr/local/etc/rc.d/apache.sh"
    else
        foo=`/usr/local/sbin/httpd -V | grep SERVER_CONFIG_FILE | grep 'apache24'`
	if test "$foo" = ""; then
	    INSTALL_APACHE_CONFIG="/usr/local/etc/apache22"
	    APACHE_VERSION="22"
	    APACHE_START_COMMAND="/usr/local/etc/rc.d/apache22"
	else
	    INSTALL_APACHE_CONFIG="/usr/local/etc/apache24"
	    APACHE_VERSION="24"
	    APACHE_START_COMMAND="/usr/local/etc/rc.d/apache24"
	fi
    fi
])
AC_SUBST(INSTALL_APACHE_CONFIG)
AC_SUBST(APACHE_VERSION)
AC_SUBST(APACHE_START_COMMAND)

#
# Path to garcia installation
#
AC_ARG_WITH(brainstem,
[  --with-brainstem=<DIR> Specify the path to the brainstem installation.],
[
    if test x"$withval" != x""; then
	BRAINSTEM_DIR="$withval"
    else
	AC_MSG_ERROR([You must specify a brainstem directory]);
    fi
],[
    BRAINSTEM_DIR=""
])
AC_SUBST(BRAINSTEM_DIR)


#
# Optionally build with optimization or aggressive non-optimization
# (Actually three options: on, off or default.)
#
AC_ARG_ENABLE(debug,
[  --enable-debug        Build with debug flags (-g -DDEBUG)
  --disable-debug       Build with optimization flags (-O2 -DNDEBUG -UDEBUG)])

if test "$enable_debug" = "yes"; then
	OPT_CFLAGS="-g -DDEBUG";
else
	if test "$enable_debug" = "no"; then
		OPT_CFLAGS="-O2 -DNDEBUG -UDEBUG";
	else
		OPT_CFLAGS="-g -O";
	fi
fi
AC_SUBST(OPT_CFLAGS)

#
# Disable event system. Relies on Elvin. On by default.
#
AC_ARG_ENABLE(events,
[  --disable-events      Disable events (requires Elvin libraries)])

if test "$enable_events" = "no"; then
	eventfiles="";
        EVENTSYS=0;
else
	eventfiles="event/GNUmakefile clientside/lib/event/GNUmakefile \
		    event/etc/elvind-boss.conf event/etc/elvind-ops.conf \
		    event/etc/elvind-inetd.conf event/etc/GNUmakefile\
		    event/sched/GNUmakefile \
		    event/new_sched/GNUmakefile \
                    event/example/GNUmakefile event/example/tbsend.pl \
		    event/example/tbrecv.pl event/example/tbsend-short.pl \
                    event/example/tbsend.py event/example/tbrecv.py \
		    event/example/eventdebug.pl \
		    event/proxy/GNUmakefile \
		    event/monitoring/GNUmakefile \		    
		    event/nsetrafgen/GNUmakefile \
		    event/nsetrafgen/nseinput.tcl \
		    event/nsetrafgen/nse-makepatch \
		    event/stated/waitForState \
		    event/stated/GNUmakefile event/stated/stated"

	optional_subdirs="$optional_subdirs event";
        EVENTSYS=1;
fi
AC_SUBST(EVENTSYS)

#
# Quickie pelab support.
#
if test $PELABSUPPORT -eq 0; then
	pelabfiles="";
else
	pelabfiles="pelab/GNUmakefile pelab/db/GNUmakefile \
		    pelab/bgmon/GNUmakefile ";
	optional_subdirs="$optional_subdirs pelab";
fi

#
# Mobile networking support.
#
if test $MOBILESUPPORT -eq 0; then
	mobilefiles="";
else
	mobilefiles="mobile/GNUmakefile \
	             clientside/mobile/GNUmakefile";
	optional_subdirs="$optional_subdirs mobile";
fi

#
# Enable Windows support.
# Right now this means NTFS support in imagezip, maybe more things later.
# Relies on Linux NTFS library.
#
AC_ARG_ENABLE(windows,
[  --enable-windows      Enable Windows XP support (default)])

if test "$enable_windows" = "no"; then
	WINSUPPORT=0;
elif test "$enable_windows" = "yes"; then
	WINSUPPORT=1;
fi

if test $WINSUPPORT -eq 0; then
	winfiles="";
else
	if test $LINUX_FSNODE -ne 0; then
		AC_MSG_ERROR([You cannot define LINUX_FSNODE with windows support]);
	fi
	winfiles="clientside/os/imagezip/ntfs/GNUmakefile \
		  clientside/os/imagezip/ntfs/liblocale/GNUmakefile \
		  clientside/os/imagezip/ntfs/libntfs/GNUmakefile \
		  clientside/os/imagezip/fat/GNUmakefile"
	optional_subdirs="$optional_subdirs";
        AC_DEFINE_UNQUOTED(WINSUPPORT, 1, [Support Windows images])
fi

#
# Check for ulsshxmlrpc header
#

AC_CHECK_HEADERS([ulxmlrpcpp/ulxr_config.h],
		 [AC_DEFINE(HAVE_ULXMLRPCPP, [], [XXX])
		  HAVE_ULXMLRPCPP="yes"])
AC_SUBST(HAVE_ULXMLRPCPP)

#
# Check for the robot vision system dependencies.
#
AC_CHECK_HEADERS([linux/videodev.h],
		 [AC_DEFINE(HAVE_LINUX_VIDEODEV_H)
		  HAVE_LINUX_VIDEODEV_H="yes"])
AC_CHECK_PROG(GTK_CONFIG, gtk-config, gtk-config)

AC_ARG_ENABLE(mezzanine,
[  --enable-mezzanine    Enable mezzanine support])

if test x"$HAVE_LINUX_VIDEODEV_H" != x"" && test x"$GTK_CONFIG" != x""; then
    HAVE_MEZZANINE="$enable_mezzanine"
    AC_DEFINE([HAVE_MEZZANINE], [], [Obsolete])
else
    HAVE_MEZZANINE="no"
fi
AC_SUBST(HAVE_MEZZANINE)

#
# Check for a few things used by assign
#
AC_LANG_PUSH([C++])

#
# Check for Xerces (required for XML support in assign).
#
AC_CHECK_HEADER([xercesc/dom/DOM.hpp],[HAVE_XERCES=yes])

#
# Check for newer versions of boost, which have moved some headers
#
AC_CHECK_HEADER([boost/property_map/property_map.hpp],[NEWER_BOOST=yes])

AC_LANG_POP([C++])
AC_SUBST(HAVE_XERCES)
AC_SUBST(NEWER_BOOST)

#
# Are we building with Clang?
# Taken from MesaLib configure via chromium.
#
AC_MSG_CHECKING([if compiling with clang])
AC_COMPILE_IFELSE(
[AC_LANG_PROGRAM([], [[
#ifndef __clang__
       not clang
#endif
]])],
[USING_CLANG=yes], [USING_CLANG=no])
AC_MSG_RESULT([$USING_CLANG])
AC_SUBST(USING_CLANG)

#
# Testing mode.  In testing mode scripts should not effect hardware state.
# This is designed to be used with the testsuite software which operates
# on a test copy of the DB.
#
AC_ARG_ENABLE(testmode,
[  --enable-testmode     Enable test mode
  --disable-testmode    Disable test mode])

if test "$enable_testmode" = "yes"; then
	TESTMODE=1
else
	TESTMODE=0
fi
AC_SUBST(TESTMODE)

# Make sure $INSTALL is valid at any depth in our tree, i.e. make it absoulte.
# This can be needed when no valid install is found and autoconf falls back on
# the supplied install.sh, but we called 'configure' with a relative path.
AC_PROG_INSTALL
[case "$INSTALL" in
..*)
        INSTALL=`pwd`/$INSTALL
        ;;
esac]

AC_PATH_PROG(RSYNC, rsync, "", [${PATH}])
if test x"$RSYNC" = x"" || test ! -x "$RSYNC"; then
    AC_MSG_WARN([Rsync is required for logholes to work, see www.rsync.org.])
fi

# Turn on the new fancy banner - normally turned on only at Utah, but
# overridable for other sites
if test "$TBMAINSITE" = 1; then
    FANCYBANNER=1
fi

# Mailman has been flushed
if test "$MAILMANSUPPORT" = 1; then
    AC_MSG_WARN([Forcing MAILMANSUPPORT off, no longer supported. Change your defs files!])
    MAILMANSUPPORT=0
fi

#
# Get rid of old third-party distributions in the source tree since we now
# unpack them in the build tree. In the case of tg2.0, it actually breaks
# the build if the old tree exists.
#
echo -n "Checking for errant distributions in src dir ... ";
for baddir in trafgen/tg2.0 linktest/iperf/iperf-2.0.2 linktest/rude/rude-0.70; do
    if test -e "$srcdir/event/$baddir" -o -e "$srcdir/clientside/event/$baddir"; then
	rm -rf $srcdir/event/$baddir $srcdir/clientside/event/$baddir
	echo -n "$baddir "
    fi
done
echo "done"

#
# Check for protogeni rspec.
#
if test "$PROTOGENI_SUPPORT" = "1" -a $ELABINELAB = "0" -a -e "$srcdir/.git"; then
   if test ! -e "$srcdir/protogeni/rspec-geni/.git"; then
	AC_MSG_WARN([protogeni/rspec-geni submodule not initialized yet]);
	echo "Please cd into your source directory and run:"
	echo "    git submodule init"
	echo "    git submodule update"
	echo "Then rerun configure in your object tree"
	exit 1;
   fi
   module_status=`cd $srcdir; git submodule status protogeni/rspec-geni`
   if test $? -ne 0; then
       AC_MSG_WARN([Cannot get submodule status for protogeni/rspec-geni]);
       exit 1;
   fi
   if echo '$module_status' | grep -E '^\+'; then
	AC_MSG_WARN([protogeni/rspec-geni submodule is out of date]);
	echo "Please cd into your source directory and run:"
	echo "    git submodule update protogeni/rspec-geni"
	echo "Then rerun configure in your object tree"
	exit 1;
   fi
fi

#
# Set the Protogeni URL, which depends on the the port and name.
#
if test -z "$PROTOGENI_RPCNAME"; then
    PROTOGENI_RPCNAME=$WWW
fi

if test $PROTOGENI_RPCPORT -eq 443; then
    AC_MSG_ERROR([The ProtoGENI RPC port cannot be 443 (https)]);
else
    PROTOGENI_URL="https://$PROTOGENI_RPCNAME:$PROTOGENI_RPCPORT/protogeni/xmlrpc"
fi

#
# Check to see if snmpit is a plain file, delete it if so. It is now
# a directory. This only matters when reconfiguring an existing tree.
#
if test -f "tbsetup/snmpit"; then
    echo "Removing old snmpit file, now a directory";
    /bin/rm -f tbsetup/snmpit
    if test $? -ne 0; then
        AC_MSG_ERROR([Cannot remove old tbsetup/snmpit file]);
    fi 
fi

#
# Determine the timezone (stupidity in PHP5, see apache/php.ini)
#
if test -e "$srcdir/utils/gettimezone.pl"; then
    echo -n "Checking to see what timezone we are ... ";
    ZONE=`$PERL $srcdir/utils/gettimezone.pl`
    if test $? -ne 0; then
        AC_MSG_WARN([Cannot find gettimezone script; defaulting to $OURTIMEZONE]);
    else
        OURTIMEZONE=$ZONE
    fi
    echo "$OURTIMEZONE"
else
    AC_MSG_WARN([Cannot find gettimezone script; defaulting to $OURTIMEZONE]);
fi

#
# Merge build
#
MERGE_BUILD=0
MERGE_BUILD_SANDBOX=
if test -e "$srcdir/.merge-build"; then
   merge_sandbox=`grep source-tree "$srcdir/.merge-build" | cut -d' ' -f2`
   merge_tree=`grep merge-tree "$srcdir/.merge-build" | cut -d' ' -f2`
   if test "$srcdir" -ef "$srcdir/$merge_sandbox/$merge_tree"; then
      MERGE_BUILD=1
      MERGE_BUILD_SANDBOX=$srcdir/$merge_sandbox
      echo "#/bin/sh"   > sync
      echo              >> sync
      echo "cd \"$srcdir\"" >> sync
      echo "utils/merge-build sync" >> sync
      chmod +x sync
      echo "Merge-build enabled"
   fi
fi
AC_SUBST(MERGE_BUILD)
AC_SUBST(MERGE_BUILD_SANDBOX)

outfiles="$outfiles Makeconf GNUmakefile \
	assign/GNUmakefile \
        named/GNUmakefile firewall/GNUmakefile fwrules/GNUmakefile \
	ssl/GNUmakefile ssl/mksig ssl/usercert.cnf ssl/mkserial \
	db/GNUmakefile \
	db/EmulabConstants.pm db/EmulabFeatures.pm db/Experiment.pm \
	db/Firewall.pm db/Group.pm db/Image.pm db/Interface.pm \
	db/Lan.pm db/Logfile.pm db/Node.pm db/NodeType.pm db/OSinfo.pm \
	db/Project.pm db/User.pm db/VirtExperiment.pm \
	db/nalloc db/nfree db/if2port db/backup \
	db/webcontrol db/node_status db/genelists db/genelists.proxy \
	db/dumperrorlog.proxy \
	db/setsitevar db/audit db/changeuid db/changepid \
	db/libdb.pm db/libtbdb.pm db/inuse db/avail db/nodeip db/showgraph \
	db/emdb.pm db/emdbi.pm db/emutil.pm \
	db/dhcpd_makeconf db/nodelog db/unixgroups \
	db/dbcheck db/interswitch db/dbboot db/schemacheck \
	db/sitevarscheck db/dbfillcheck db/libadminctrl.pm \
	db/update_permissions \
	db/grabron db/stategraph db/readycount \
	db/idletimes db/idlemail db/xmlconvert \
	db/libdb.py db/elabinelab_bossinit db/Reservation.pm \
	ipod/GNUmakefile \
	os/GNUmakefile os/split-image.sh \
	pxe/GNUmakefile pxe/bootinfo.restart \
	security/GNUmakefile security/lastlog_daemon \
        sensors/GNUmakefile \
	sensors/and/GNUmakefile sensors/and/and-emulab.conf \
	sensors/powermon/GNUmakefile sensors/powermon/powermon \
	sensors/nfstrace/GNUmakefile sensors/nfstrace/nfstrace.init \
	sensors/nfstrace/nfsdump2/GNUmakefile \
	account/GNUmakefile account/tbacct \
	account/addpubkey account/addsfskey account/genpubkeys \
	account/quotamail account/mkusercert account/newproj account/newuser \
	backend/GNUmakefile backend/moduserinfo backend/newgroup \
	backend/newmmlist backend/editexp backend/editimageid \
	backend/editnodetype backend/editsitevars backend/newimageid \
	backend/editgroup backend/newimageid_ez \
	tbsetup/GNUmakefile tbsetup/console_setup tbsetup/spewlogfile \
	tbsetup/snmpit/GNUmakefile  \
	tbsetup/spewrpmtar tbsetup/gentopofile tbsetup/power_5gstore.pm \
	tbsetup/console_reset tbsetup/bwconfig tbsetup/power_rpc27.pm \
	tbsetup/power_mail.pm tbsetup/power_whol.pm \
	tbsetup/os_load tbsetup/os_setup tbsetup/os_select tbsetup/power \
	tbsetup/node_reboot tbsetup/nscheck tbsetup/pxe_select \
	tbsetup/resetvlans tbsetup/rmuser tbsetup/rmproj \
	tbsetup/sched_reload tbsetup/sched_reserve tbsetup/reload_daemon \
	tbsetup/batchexp tbsetup/batch_daemon tbsetup/repos_daemon \
	tbsetup/wanlinkinfo tbsetup/wanassign \
	tbsetup/swapexp	tbsetup/endexp tbsetup/elabinelab \
	tbsetup/eventsys.proxy \
	tbsetup/ns2ir/GNUmakefile \
	tbsetup/ns2ir/parse.tcl tbsetup/ns2ir/tb_compat.tcl \
	tbsetup/ns2ir/parse-ns tbsetup/ns2ir/parse.proxy \
	tbsetup/ns2ir/sim.tcl tbsetup/nseswap tbsetup/nseparse/GNUmakefile \
	tbsetup/nseparse/nse.parse.proxy tbsetup/nseparse/parse-nse \
	tbsetup/nseparse/nse.parse.tcl \
	tbsetup/nsverify/GNUmakefile tbsetup/nsverify/nstbparse \
	tbsetup/nsverify/verify-ns \
	tbsetup/db2ns \
	tbsetup/tbprerun tbsetup/tbswap tbsetup/tbend tbsetup/tbrestart \
	tbsetup/tbreport tbsetup/named_setup tbsetup/exports_setup \
	tbsetup/checkpass/GNUmakefile tbsetup/assign_wrapper tbsetup/ptopgen \
	tbsetup/assign_wrapper2 \
	tbsetup/node_update \
	tbsetup/savelogs tbsetup/setgroups \
	tbsetup/savelogs.proxy tbsetup/rmgroup tbsetup/mkexpdir \
	tbsetup/node_control tbsetup/node_attributes \
        tbsetup/mkgroup tbsetup/eventsys_start \
	tbsetup/eventsys_control \
	tbsetup/mkproj tbsetup/libtestbed.pm \
	tbsetup/vnode_setup tbsetup/staticroutes \
	tbsetup/console_setup.proxy tbsetup/exports_setup.proxy \
	tbsetup/smbpasswd_setup.proxy \
	tbsetup/checkports tbsetup/libaudit.pm \
	tbsetup/libreboot.pm tbsetup/libosload.pm tbsetup/libadminmfs.pm \
	tbsetup/sfskey_update tbsetup/sfskey_update.proxy \
	tbsetup/idleswap tbsetup/switchmac \
	tbsetup/newnode_reboot \
        tbsetup/libtestbed.py \
	tbsetup/libArchive.pm tbsetup/archive_control \
	tbsetup/tarfiles_setup \
	tbsetup/fetchtar.proxy tbsetup/webfrisbeekiller \
	tbsetup/tcpp \
	tbsetup/plab/GNUmakefile tbsetup/plab/libplab.py \
        tbsetup/plab/mod_dslice.py tbsetup/plab/mod_PLC.py \
        tbsetup/plab/mod_PLCNM.py \
	tbsetup/plab/plabslice tbsetup/plab/plabnode tbsetup/plab/plabrenewd \
        tbsetup/plab/plabrenewonce \
	tbsetup/plab/plabmetrics tbsetup/plab/plabstats \
	tbsetup/plab/plabmonitord tbsetup/plab/libplabmon.pm \
        tbsetup/plab/plabmon_badpool.pm tbsetup/plab/plabmon_goodpool.pm \
        tbsetup/plab/plablinkdata \
	tbsetup/plab/libdslice/GNUmakefile tbsetup/plab/etc/GNUmakefile \
	tbsetup/plab/plabdist tbsetup/plab/plabhttpd \
	tbsetup/plab/plabdiscover tbsetup/plab/etc/netbed_files/GNUmakefile \
	tbsetup/ipassign/GNUmakefile tbsetup/ipassign/src/GNUmakefile \
	tbsetup/ipassign/ipassign_wrapper tbsetup/assign_prepass \
	tbsetup/panic tbsetup/tbrsync tbsetup/nfstrace \
	tbsetup/checkup/GNUmakefile tbsetup/checkup/checkup_daemon \
	tbsetup/libtblog.pm tbsetup/template_cvsroot/GNUmakefile \
	tmcd/GNUmakefile tmcd/tmcd.restart \
	utils/GNUmakefile utils/vlandiff utils/vlansync utils/delay_config \
	utils/sshtb utils/create_image utils/node_admin \
	utils/firstuser utils/export_tables utils/eventping \
	utils/cvsupd.pl utils/newnode utils/grantnodetype \
	utils/nsgen/GNUmakefile utils/nsgen/webnsgen \
	utils/link_config utils/import_commitlog \
	utils/opsreboot utils/deletenode utils/spewleds \
	utils/grabwebcams utils/loghole utils/webcopy \
	utils/setdest utils/grabswitchconfig \
        utils/backupswitches utils/setbuildinfo utils/checkquota \
	utils/spewconlog utils/xlogin \
	utils/opsdb_control utils/opsdb_control.proxy \
	utils/remove_old_www utils/epmodeset \
	utils/mkblob utils/rmblob utils/ctrladdr utils/tcppd \
	utils/mktestbedtest utils/pxelinux_makeconf \
	utils/addvpubaddr utils/attend utils/atten utils/addrfdevice \
	utils/addrfpath utils/reserve utils/predict utils/notify-reservations \
	utils/setzfsquotas utils/checkipmi \
	wbstore/GNUmakefile \
	www/GNUmakefile www/defs.php3 www/dbdefs.php3 www/xmlrpc.php3 \
	www/xmlrpcpipe.php3 \
	www/swish.conf www/websearch \
	www/garcia-telemetry/GNUmakefile www/tutorial/GNUmakefile \
	www/sec-check/GNUmakefile www/emusearch.xml \
	vis/GNUmakefile vis/webvistopology vis/dbvistopology \
	vis/prerender vis/prerender_all vis/render \
	vis/floormap vis/webfloormap \
	rc.d/GNUmakefile rc.d/2.mysql-server.sh rc.d/3.testbed.sh \
	rc.d/2.elvind.sh rc.d/3.plab.sh rc.d/2.dhcpd.sh rc.d/3.and.sh \
	rc.d/3.elvin_gateway.sh rc.d/pelab.sh rc.d/capture.sh \
	rc.d/3.mfrisbeed.sh rc.d/3.mfrisbeed-subboss.sh rc.d/3.mfrisbeed-ops.sh \
	tools/GNUmakefile rc.d/1.mysql-server.sh tools/svn/GNUmakefile \
        tools/webcamapplet/GNUmakefile tools/whol/GNUmakefile \
        tools/selectapplet/GNUmakefile \
	$eventfiles \
	$winfiles \
	$pelabfiles \
	$mobilefiles \
	apache/GNUmakefile apache/php.ini \
        xmlrpc/GNUmakefile xmlrpc/emulabserver.py \
	xmlrpc/sslxmlrpc_server.py xmlrpc/webxmlrpc xmlrpc/xmlrpcbag \
	cdrom/GNUmakefile cdrom/tbbootconfig/GNUmakefile \
	cdrom/groklilo/GNUmakefile \
	autofs/GNUmakefile flash/GNUmakefile \
	dhcpd/dhcpd.conf.template dhcpd/GNUmakefile \
	dhcpd/dhcpd.conf.subboss.template \
	ntpd/GNUmakefile \
	ntpd/ntp.conf-client ntpd/ntp.conf-server ntpd/ntp.conf-external \
	install/GNUmakefile install/installvars.pm install/emulab-install \
	install/ops-install install/boss-install install/fs-install \
	install/load-descriptors install/dump-descriptors \
	install/newnode_sshkeys/GNUmakefile install/smb.conf.head \
        install/clrhouse-install install/genirack/GNUmakefile \
	install/powder-fixed/GNUmakefile install/powder-bus/GNUmakefile \
	install/libinstall.pm install/update-install install/update-testbed \
	mote/GNUmakefile mote/tbuisp mote/tbsgmotepower mote/newmote \
	mote/sgtools/GNUmakefile \
        protogeni/GNUmakefile protogeni/security/GNUmakefile \
        protogeni/xmlrpc/GNUmakefile protogeni/lib/GNUmakefile \
        protogeni/scripts/GNUmakefile protogeni/etc/GNUmakefile \
        protogeni/test/GNUmakefile protogeni/pubxmlrpc/GNUmakefile \
	protogeni/event/GNUmakefile \
	protogeni/rspec-emulab/GNUmakefile \
        protogeni/rspec-emulab/0.1/GNUmakefile \
	protogeni/rspec-emulab/0.2/GNUmakefile \
	protogeni/rspec-emulab/2/GNUmakefile \
        apt/GNUmakefile \
        powder/GNUmakefile powder/sasproxy/GNUmakefile \
        collab/GNUmakefile \
	collab/exp-vis/GNUmakefile collab/exp-vis/fetch-vis \
        scopus/GNUmakefile \
	node_usage/GNUmakefile node_usage/mk-plots \
	node_usage/analy node_usage/publish \
	node_usage/analy2 node_usage/refresh \
	node_usage/from_ptop node_usage/sanity \
	node_usage/gather node_usage/mk-php-pages \
	node_usage/get-start-date"

#
# While it would be nice to use the configure setup in the clientside subdir,
# this turned out to be a major headache. Instead, just duplicate the file
# lists here and in clientside.
#
outfiles="$outfiles clientside/GNUmakefile clientside/setversion \
 clientside/lib/GNUmakefile clientside/lib/libtb/GNUmakefile \
 clientside/lib/tmcd/GNUmakefile \
 clientside/GNUmakefile clientside/event/GNUmakefile \
 clientside/event/program-agent/GNUmakefile \
 clientside/event/disk-agent/GNUmakefile \
 clientside/tools/GNUmakefile clientside/tools/pcapper/GNUmakefile \
 clientside/tools/teachswitch/GNUmakefile \
 clientside/sensors/GNUmakefile clientside/sensors/slothd/GNUmakefile \
 clientside/sensors/slothd/sdisrunning clientside/sensors/slothd/sddeploy \
 clientside/sensors/canaryd/GNUmakefile \
 clientside/sensors/canaryd/feedbacklogs \
 clientside/os/GNUmakefile clientside/os/syncd/GNUmakefile \
 clientside/event/link-agent/GNUmakefile \
 clientside/event/bs-agent/GNUmakefile \
 clientside/event/proxy/GNUmakefile \
 clientside/event/tevc/GNUmakefile \
 clientside/event/trafgen/GNUmakefile \
 clientside/event/linktest/GNUmakefile \
 clientside/event/linktest/iperf/GNUmakefile \
 clientside/event/linktest/rude/GNUmakefile \
 clientside/event/linktest/weblinktest \
 clientside/event/linktest/linktest.proxy \
 clientside/event/linktest/linktest_control \
 clientside/event/linktest/run_linktest.pl \
 clientside/event/delay-agent/GNUmakefile \
 clientside/tmcc/GNUmakefile \
 clientside/tmcc/common/GNUmakefile clientside/tmcc/common/config/GNUmakefile \
 clientside/tmcc/freebsd/GNUmakefile clientside/tmcc/freebsd/init/GNUmakefile \
 clientside/tmcc/freebsd/init/4/GNUmakefile \
 clientside/tmcc/freebsd/init/5/GNUmakefile \
 clientside/tmcc/freebsd/init/6/GNUmakefile \
 clientside/tmcc/freebsd/init/7/GNUmakefile \
 clientside/tmcc/freebsd/init/8/GNUmakefile \
 clientside/tmcc/freebsd/init/9/GNUmakefile \
 clientside/tmcc/freebsd/init/10/GNUmakefile \
 clientside/tmcc/freebsd/init/10.3/GNUmakefile \
 clientside/tmcc/freebsd/init/10.4/GNUmakefile \
 clientside/tmcc/freebsd/init/11/GNUmakefile \
 clientside/tmcc/freebsd/init/11.2/GNUmakefile \
 clientside/tmcc/freebsd/init/12/GNUmakefile \
 clientside/tmcc/freebsd/init/13/GNUmakefile \
 clientside/tmcc/freebsd/supfile clientside/tmcc/freebsd/sethostname \
 clientside/tmcc/linux/GNUmakefile clientside/tmcc/linux/supfile \
 clientside/tmcc/linux/sethostname.dhclient \
 clientside/tmcc/linux9/GNUmakefile clientside/tmcc/linux9/supfile \
 clientside/tmcc/fedora/GNUmakefile clientside/tmcc/fedora/supfile \
 clientside/tmcc/fedora15/GNUmakefile \
 clientside/tmcc/linux-sg/GNUmakefile clientside/tmcc/ubuntu7/GNUmakefile \
 clientside/tmcc/centos6/GNUmakefile \
 clientside/tmcc/centos7/GNUmakefile \
 clientside/tmcc/centos8/GNUmakefile \
 clientside/tmcc/onie/GNUmakefile \
 clientside/tmcc/ubuntu10/GNUmakefile \
 clientside/tmcc/ubuntu11/GNUmakefile \
 clientside/tmcc/ubuntu14/GNUmakefile \
 clientside/tmcc/ubuntu15/GNUmakefile \
 clientside/tmcc/ubuntu16/GNUmakefile \
 clientside/tmcc/ubuntu16-ms/GNUmakefile \
 clientside/tmcc/ubuntu18/GNUmakefile \
 clientside/tmcc/ubuntu18-ms/GNUmakefile \
 clientside/tmcc/ubuntu18-ppc64le/GNUmakefile \
 clientside/tmcc/ubuntu20/GNUmakefile \
 clientside/tmcc/ubuntu20-ms/GNUmakefile \
 clientside/tmcc/ubuntu20-ppc64le/GNUmakefile \
 clientside/tmcc/linux-ms/GNUmakefile \
 clientside/tmcc/archlinux/GNUmakefile \
 clientside/tmcc/alpine/GNUmakefile \
 clientside/tmcc/freebsd5/GNUmakefile clientside/tmcc/freebsd5/supfile \
 clientside/tmcc/freebsd6/GNUmakefile clientside/tmcc/freebsd6/supfile \
 clientside/tmcc/freebsd6/netif-emulab \
 clientside/tmcc/freebsd7/GNUmakefile clientside/tmcc/freebsd7/netif-emulab \
 clientside/tmcc/freebsd9/GNUmakefile clientside/tmcc/freebsd9/netif-emulab \
 clientside/tmcc/freebsd10/GNUmakefile clientside/tmcc/freebsd10/netif-emulab \
 clientside/tmcc/freebsd11/GNUmakefile clientside/tmcc/freebsd11/netif-emulab \
 clientside/tmcc/freebsd12/GNUmakefile clientside/tmcc/freebsd12/netif-emulab \
 clientside/tmcc/freebsd13/GNUmakefile clientside/tmcc/freebsd13/netif_emulab \
 clientside/tmcc/cygwinxp/GNUmakefile clientside/tmcc/dp/GNUmakefile \
 clientside/tmcc/openbsd/GNUmakefile clientside/tmcc/ron/GNUmakefile \
 clientside/tmcc/plab/GNUmakefile clientside/tmcc/cygwinseven/GNUmakefile \
 clientside/os/dijkstra/GNUmakefile clientside/os/genhostsfile/GNUmakefile \
 clientside/os/growdisk/GNUmakefile \
 clientside/os/bootinfo/GNUmakefile \
 clientside/os/zapdisk/GNUmakefile \
 clientside/os/frisbee.redux/GNUmakefile \
 clientside/os/imagezip/GNUmakefile \
 clientside/os/imagezip/mbr/GNUmakefile \
 clientside/os/imagezip/gpt/GNUmakefile \
 clientside/os/imagezip/ffs/GNUmakefile \
 clientside/os/imagezip/extfs/GNUmakefile \
 clientside/os/imagezip/hashmap/GNUmakefile \
 clientside/os/imagezip/libndz/GNUmakefile \
 clientside/os/capture/GNUmakefile \
 clientside/tip/GNUmakefile clientside/tip/console \
 clientside/xmlrpc/GNUmakefile clientside/xmlrpc/emulabclient.py \
 clientside/xmlrpc/sslxmlrpc_client.py \
 clientside/xmlrpc/script_wrapper.py clientside/xmlrpc/libxmlrpc.pm \
 clientside/protogeni/GNUmakefile"
 
#
# Do this for easy distclean.
#
DISTCLEAN_FILES="$outfiles"
AC_SUBST(DISTCLEAN_FILES)

AC_CONFIG_FILES([$outfiles])
AC_OUTPUT
