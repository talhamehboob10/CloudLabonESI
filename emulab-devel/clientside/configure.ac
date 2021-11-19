#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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
AC_PREREQ(2.69)

AC_INIT(Makeconf.in)
AC_CONFIG_AUX_DIR(autoconf)
AC_CONFIG_HEADER(config.h)
AC_CANONICAL_HOST

AC_PROG_CPP
AC_PROG_CXX
AC_PROG_LN_S
AC_PROG_RANLIB
AC_PROG_MKDIR_P
AC_PROG_INSTALL
AC_PATH_PROG(SUDO,sudo)
if test -z "$SUDO" ; then
    AC_MSG_ERROR([no acceptable sudo found in \$PATH])
fi
AC_PATH_PROG(AR, ar)
if test -z "$AR" ; then
    AC_MSG_ERROR([no acceptable ar found in \$PATH])
fi
AC_PATH_PROG(STRIP, strip)
if test -z "$STRIP" ; then
    AC_MSG_ERROR([no acceptable strip found in \$PATH])
fi
AC_PATH_PROG(RM, rm)
if test -z "$RM" ; then
    AC_MSG_ERROR([no acceptable rm found in \$PATH])
fi
AC_PATH_PROG(CP, cp)
if test -z "$CP" ; then
    AC_MSG_ERROR([no acceptable cp found in \$PATH])
fi
AC_PATH_PROG(YACC, byacc)
if test -z "$YACC" ; then
    AC_PATH_PROG(YACC, yacc)
    if test -z "$YACC" ; then
        AC_MSG_ERROR([no byacc nor yacc found in \$PATH])
    fi
fi
AC_PATH_PROG(TAR, tar)
if test -z "$TAR" ; then
    AC_MSG_ERROR([no tar found in \$PATH])
fi
AC_PATH_PROG(RPM, rpm, rpm)
if test -z "$RPM" ; then
    AC_MSG_ERROR([no rpm found in \$PATH])
fi
AC_PATH_PROG(ELVIN_CONFIG,elvin-config)

# Need this for Makeconf.
AC_SUBST(PATH)

#
# Flag build as clientside only, not withing full Emulab build
#
WITH_EMULAB=0
AC_SUBST(WITH_EMULAB)

# TPM stuff. See option below.
TPM=0
AC_SUBST(TPM)

# Need this in a couple of places that share with Emulab.
BOSSNODE="boss"
AC_SUBST(BOSSNODE)

#
# Elvin compat option, which we	still need. Always turn on event system.
#
AC_SUBST(ELVIN_COMPAT)
ELVIN_COMPAT=0
AC_SUBST(EVENTSYS)
EVENTSYS=1

AC_SUBST(DISABLE_NAMED_SETUP)
DISABLE_NAMED_SETUP=0

AC_SUBST(CLIENT_ETCDIR)
AC_SUBST(CLIENT_BINDIR)
AC_SUBST(CLIENT_VARDIR)
AC_SUBST(CLIENT_MANDIR)
CLIENT_ETCDIR="/etc/emulab"
CLIENT_BINDIR="/usr/local/etc/emulab"
CLIENT_VARDIR="/var/emulab"
CLIENT_MANDIR="/usr/local/man"

# XXX compat. We have no business expanding these on the client side!
AC_SUBST(PROJROOT_DIR)
AC_SUBST(EVENTSERVER)
AC_SUBST(NOSHAREDFS)
PROJROOT_DIR="/proj"
EVENTSERVER="event-server"
NOSHAREDFS=0

TBLOGFACIL="local5"
LOG_TESTBED=`echo "LOG_$TBLOGFACIL" | tr a-z A-Z`
AC_DEFINE_UNQUOTED(LOG_TESTBED, $LOG_TESTBED, [Syslog log facility for Emulab daemons])
AC_SUBST(LOG_TESTBED)
AC_SUBST(TBLOGFACIL)

#
# Allow enabling of NTFS support in imagezip
#
AC_SUBST(OUTERBOSS_NODENAME)
AC_SUBST(WINSUPPORT)
OUTERBOSS_NODENAME=""
WINSUPPORT=0

#
# Variables for Windows Unattended setup files.
#
AC_SUBST(WINDOWS_ORGNAME)
AC_SUBST(WINDOWS_OWNER)
AC_SUBST(WINDOWS_TIMEZONE)
AC_SUBST(WINDOWS_KEY_7PRO_X86)

#
# Allow tbdefs file that is supplied to full emulab build
#
AC_ARG_WITH(TBDEFS,
[  --with-TBDEFS=name	Specify definitions file (defs-default default)],
[
    if test "$withval" = "yes"; then
	AC_MSG_ERROR([Invalid TBDEFS - Must specify the value])
    fi
    TBDEFS="$withval"
    TBPATH=`dirname $withval`

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
])

AC_ARG_ENABLE(windows,
[  --enable-windows[[=yes/no]]  Enable Windows FAT/NTFS support in imagezip [[default=no]]])

if test "$enable_windows" = "no"; then
	WINSUPPORT=0;
elif test "$enable_windows" = "yes"; then
	WINSUPPORT=1;
fi

if test $WINSUPPORT -eq 0; then
	winfiles="";
else
	winfiles="os/imagezip/ntfs/GNUmakefile \
		  os/imagezip/ntfs/liblocale/GNUmakefile \
		  os/imagezip/ntfs/libntfs/GNUmakefile \
		  os/imagezip/fat/GNUmakefile"
        AC_DEFINE_UNQUOTED(WINSUPPORT, 1, [Support Windows images])
fi

#
# Allow command line option, since might not have a defs file.
#
AC_ARG_ENABLE(elvin_compat,
[  --enable-elvin_compat[[=yes/no]]  Include Elvin Hash compat [[default=no]]])

if test "$enable_elvin_compat" = "yes"; then
    ELVIN_COMPAT=1
fi
if test $ELVIN_COMPAT -eq 1; then
    AC_DEFINE_UNQUOTED(ELVIN_COMPAT, 1, [Obsolete])
fi

AC_ARG_ENABLE(TPM,
[  --enable-TPM[[=yes/no]]           Include TPM support [[default=no]]])

if test "$enable_TPM" = "yes"; then
    TPM=1
fi
if test $TPM -eq 1; then
    AC_DEFINE_UNQUOTED(TPM, 1, [Something about TPM])
fi

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

# Conditional files created for various versions of Windows
# based on which variables are defined.

# Win7 Pro x86
if test -n "${WINDOWS_KEY_7PRO_X86}"; then
   WIN7_IMNAME="Windows 7 PROFESSIONAL"
   sed -e "s/@WIN7_IMNAME@/$WIN7_IMNAME/" < $srcdir/tmcc/cygwinseven/unattend-x86.xml.in.tmpl > $srcdir/tmcc/cygwinseven/unattend-7pro-x86.xml.in
   winfiles="$winfiles tmcc/cygwinseven/unattend-7pro-x86.xml"
fi

# Mobile networking support
AC_SUBST(MOBILESUPPORT)
MOBILESUPPORT=0

AC_ARG_ENABLE(mobile,
[  --enable-mobile[[=yes/no]]  Enable mobile support (PhantomNet) [[default=no]]])

if test "$enable_mobile" = "no"; then
	MOBILESUPPORT=0;
elif test "$enable_mobile" = "yes"; then
	MOBILESUPPORT=1;
fi

if test $MOBILESUPPORT -eq 0; then
	mobilefiles=""
else
	mobilefiles="mobile/GNUmakefile"
        AC_DEFINE_UNQUOTED(MOBILESUPPORT, 1, [Support mobile networking])
fi


outfiles="Makeconf GNUmakefile setversion \
	  lib/GNUmakefile \
          lib/libtb/GNUmakefile \
          lib/tmcd/GNUmakefile \
          lib/event/GNUmakefile \
	  event/GNUmakefile \
	  event/program-agent/GNUmakefile \
	  event/disk-agent/GNUmakefile \
	  event/link-agent/GNUmakefile \
	  event/bs-agent/GNUmakefile \
	  event/proxy/GNUmakefile \
	  event/tevc/GNUmakefile \
	  event/trafgen/GNUmakefile \
	  event/linktest/GNUmakefile \
	  event/linktest/iperf/GNUmakefile \
	  event/linktest/rude/GNUmakefile \
	  event/linktest/weblinktest event/linktest/linktest.proxy \
	  event/linktest/linktest_control \
	  event/linktest/run_linktest.pl \
 	  event/delay-agent/GNUmakefile \
	  tools/GNUmakefile \
	  tools/pcapper/GNUmakefile \
	  tools/teachswitch/GNUmakefile \
	  sensors/GNUmakefile \
	  sensors/slothd/GNUmakefile \
	  sensors/canaryd/GNUmakefile \
	  tmcc/GNUmakefile \
	  tmcc/common/GNUmakefile tmcc/common/config/GNUmakefile \
	  tmcc/freebsd/GNUmakefile tmcc/freebsd/init/GNUmakefile \
	  tmcc/freebsd/init/4/GNUmakefile \
	  tmcc/freebsd/init/5/GNUmakefile \
	  tmcc/freebsd/init/6/GNUmakefile \
	  tmcc/freebsd/init/7/GNUmakefile \
	  tmcc/freebsd/init/8/GNUmakefile \
	  tmcc/freebsd/init/9/GNUmakefile \
	  tmcc/freebsd/init/10/GNUmakefile \
	  tmcc/freebsd/init/10.3/GNUmakefile \
	  tmcc/freebsd/init/10.4/GNUmakefile \
	  tmcc/freebsd/init/11/GNUmakefile \
	  tmcc/freebsd/init/11.2/GNUmakefile \
	  tmcc/freebsd/init/12/GNUmakefile \
	  tmcc/freebsd/init/13/GNUmakefile \
	  tmcc/freebsd/supfile tmcc/freebsd/sethostname \
	  tmcc/linux/GNUmakefile tmcc/linux/supfile \
	  tmcc/linux/sethostname.dhclient \
	  tmcc/linux9/GNUmakefile tmcc/linux9/supfile \
	  tmcc/fedora/GNUmakefile tmcc/fedora/supfile \
	  tmcc/fedora15/GNUmakefile \
	  tmcc/linux-sg/GNUmakefile tmcc/ubuntu7/GNUmakefile \
	  tmcc/ubuntu10/GNUmakefile \
	  tmcc/ubuntu11/GNUmakefile \
	  tmcc/ubuntu14/GNUmakefile \
	  tmcc/ubuntu15/GNUmakefile \
	  tmcc/ubuntu16/GNUmakefile \
	  tmcc/ubuntu16-ms/GNUmakefile \
	  tmcc/ubuntu18/GNUmakefile \
	  tmcc/ubuntu18-ms/GNUmakefile \
	  tmcc/ubuntu18-ppc64le/GNUmakefile \
	  tmcc/ubuntu20/GNUmakefile \
	  tmcc/ubuntu20-ms/GNUmakefile \
	  tmcc/ubuntu20-ppc64le/GNUmakefile \
	  tmcc/linux-ms/GNUmakefile \
	  tmcc/archlinux/GNUmakefile \
	  tmcc/alpine/GNUmakefile \
	  tmcc/freebsd5/GNUmakefile tmcc/freebsd5/supfile \
	  tmcc/freebsd6/GNUmakefile tmcc/freebsd6/supfile \
	  tmcc/freebsd6/netif-emulab \
	  tmcc/freebsd7/GNUmakefile tmcc/freebsd7/netif-emulab \
	  tmcc/freebsd9/GNUmakefile tmcc/freebsd9/netif-emulab \
	  tmcc/freebsd10/GNUmakefile tmcc/freebsd10/netif-emulab \
	  tmcc/freebsd11/GNUmakefile tmcc/freebsd11/netif-emulab \
	  tmcc/freebsd12/GNUmakefile tmcc/freebsd12/netif-emulab \
	  tmcc/freebsd13/GNUmakefile tmcc/freebsd13/netif_emulab \
	  tmcc/freenas8/GNUmakefile tmcc/freenas9/GNUmakefile \
	  tmcc/freenas11/GNUmakefile \
	  tmcc/cygwinxp/GNUmakefile tmcc/dp/GNUmakefile \
	  tmcc/openbsd/GNUmakefile tmcc/ron/GNUmakefile \
	  tmcc/plab/GNUmakefile tmcc/cygwinseven/GNUmakefile \
	  tmcc/centos6/GNUmakefile \
	  tmcc/centos7/GNUmakefile \
	  tmcc/centos8/GNUmakefile \
	  tmcc/onie/GNUmakefile \
	  tip/GNUmakefile \
	  xmlrpc/GNUmakefile xmlrpc/emulabclient.py \
	  xmlrpc/sslxmlrpc_client.py \
	  xmlrpc/script_wrapper.py xmlrpc/libxmlrpc.pm \
	  os/GNUmakefile os/syncd/GNUmakefile \
	  os/dijkstra/GNUmakefile os/genhostsfile/GNUmakefile \
	  os/frisbee.redux/GNUmakefile \
	  os/capture/GNUmakefile \
	  os/growdisk/GNUmakefile \
	  os/bootinfo/GNUmakefile \
	  os/zapdisk/GNUmakefile \
	  os/imagezip/GNUmakefile \
	  os/imagezip/libndz/GNUmakefile \
	  os/imagezip/mbr/GNUmakefile \
	  os/imagezip/gpt/GNUmakefile \
	  os/imagezip/ffs/GNUmakefile \
	  os/imagezip/extfs/GNUmakefile \
	  $winfiles \
	  os/imagezip/hashmap/GNUmakefile \
	  protogeni/GNUmakefile \
	  $mobilefiles"

#
# Do this for easy distclean.
#
DISTCLEAN_FILES="$outfiles"
AC_SUBST(DISTCLEAN_FILES)

AC_CONFIG_FILES([$outfiles])
AC_OUTPUT
