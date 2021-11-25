# New ports collection makefile for: emulab-boss
# Date created:         28 January 2003
# Whom:                 ricci@cs.utah.edu
# Updated:              1 October 2009 jwalsh@atl.lmco.com

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-boss
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none
COMMENT=	"Meta-port for an Emulab boss node"

MAINTAINER=	testbed-ops@flux.utah.edu

#
# We set this so that the mysql server port doesn't do name resolution
#
.MAKEFLAGS+=	-DSKIP_DNS_CHECK

#
# We must make sure PERL is built with this.
#
.MAKEFLAGS+=	ENABLE_SUIDPERL=yes
.if ${PORTVERSION} == "6.0"
.MAKEFLAGS+=	PERL_VERSION=5.14.4 PERL_VER=5.14 PERL_ARCH=mach
.elif ${PORTVERSION} == "5.1"
.MAKEFLAGS+=	PERL_VERSION=5.12.5 PERL_VER=5.12 PERL_ARCH=mach
.elif ${PORTVERSION} == "5.0"
.MAKEFLAGS+=	PERL_VERSION=5.12.4 PERL_VER=5.12.4 PERL_ARCH=mach
.elif (${PORTVERSION} == "3.1" || ${PORTVERSION} == "4.0")
.MAKEFLAGS+=	PERL_VERSION=5.10.1 PERL_VER=5.10.1 PERL_ARCH=mach
.elif ${PORTVERSION} == "3.0"
.MAKEFLAGS+=	PERL_VERSION=5.10.0 PERL_VER=5.10.0 PERL_ARCH=mach
.endif

#
# For SWIG, so that it doesn't feel the need to suck in php and apache
# XXX Something is broken on FreeBSD 6.X and SWIG_LANGUAGES='x y z' breaks.
#
.MAKEFLAGS+=	SWIG_LANGUAGES= 
.MAKEFLAGS+=    WANT_SWIG_PERL=yes WANT_SWIG_PYTHON=yes WANT_SWIG_TCL=yes

#
# For PHP, specify the version and that we want the Apache module
# Version is specified via PHP_VER above.
#
.MAKEFLAGS+=	WANT_PHP_MOD=yes

#
# Various ports need to agree on what version of apache. Make sure this
# agrees with what is in the emulab-ops and emulab-php* metaports.
#
.MAKEFLAGS+=	-DWITH_APACHE
.if (${PORTVERSION} == "4.0" || ${PORTVERSION} == "5.0" || ${PORTVERSION} == "5.1" || ${PORTVERSION} == "6.0")
.MAKEFLAGS+=	APACHE_PORT=www/apache22
.MAKEFLAGS+=	WITH_SUEXEC=yes
.else
.MAKEFLAGS+=	APACHE_PORT=www/apache13-modssl
.endif

#
# Use the base version of openssl
#
.MAKEFLAGS+=	WITH_OPENSSL_BASE=yes

#
# This prevents any ports from trying to run interactively - some, like the
# net-snmp port, ask silly questions without this option.
#
.MAKEFLAGS+=	-DBATCH

#
# Specifically for rpm4 so it won't drag in tetex just to format the doc!
#
.MAKEFLAGS+=	WITHOUT_LATEX=yes

#
# XXX not really build dependencies, but these Emulab-specific ports need
# to get installed before any attempt to install the standard versions.
#
.if (${PORTVERSION} == "1.7" || ${PORTVERSION} == "2.0")
BUILD_DEPENDS=	\
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/Mysql.pm:${PORTSDIR}/databases/p5-DBD-mysql${MYSQL_VER}
.elif (${PORTVERSION} == "4.0" || ${PORTVERSION} == "5.0" || \
       ${PORTVERSION} == "5.1" || ${PORTVERSION} == "6.0")
# back to a standard p5-DBD-mysql5x install
BUILD_DEPENDS=	\
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/DBD/mysql.pm:${PORTSDIR}/databases/p5-DBD-mysql${MYSQL_VER} \
	${LOCALBASE}/libexec/apache22/libphp${PHP_VER}.so:${PORTSDIR}/misc/emulab-php${PHP_VER}
.else
BUILD_DEPENDS=	\
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/Mysql.pm:${PORTSDIR}/misc/p5-DBD-mysql50-old \
	${LOCALBASE}/libexec/apache/libphp${PHP_VER}.so:${PORTSDIR}/misc/emulab-php${PHP_VER}
.endif

# XXX force our version of tcl early to prevent installing a newer version
BUILD_DEPENDS+=	tclsh8.4:${PORTSDIR}/lang/tcl84

LIB_DEPENDS= libgd.so:${PORTSDIR}/graphics/gd \
	mhash.2:${PORTSDIR}/security/mhash \
	mysqlclient:${PORTSDIR}/databases/mysql${MYSQL_VER}-client \
	snmp.4:${PORTSDIR}/misc/net-snmp4

.if ${OSMAJOR} >= 6
LIB_DEPENDS+= xerces-c.27:${PORTSDIR}/textproc/xerces-c2
.endif
.if ${OSMAJOR} >= 7
LIB_DEPENDS+= xmlrpc:${PORTSDIR}/net/xmlrpc-c
.endif

# no linuxthreads on amd64
# old libtool in ulsshxmlrpcpp causes shlibs to be whacked
.if ${OSARCH} == "i386"
.if ${OSMAJOR} < 8
LIB_DEPENDS+= lthread.[236]:${PORTSDIR}/devel/linuxthreads
.endif
LIB_DEPENDS+= ulsshxmlrpcpp.0:${PORTSDIR}/misc/ulsshxmlrpcpp
.endif

#
# Until/unless the pubsub Makefile is changed, we must include libelvin.
# This is because the pubsub libraries have to be built with ELVIN_COMPAT
# to talk to pubsub on ops, and building with compat means that the gateway
# will be built.  Building that requires elvin libraries...
#
.if defined(ELVIN_COMPAT)
LIB_DEPENDS+= vin4.2:${PORTSDIR}/misc/libelvin \
	pubsub.1:${PORTSDIR}/misc/emulab-pubsub-elvincompat
.else
LIB_DEPENDS+= pubsub.1:${PORTSDIR}/misc/emulab-pubsub
.endif

# We need the BUILD_DEPENDS above to wind up in the dependency list
RUN_DEPENDS:= ${BUILD_DEPENDS}

RUN_DEPENDS+=	\
	fping:${PORTSDIR}/net/fping \
	rsync:${PORTSDIR}/net/rsync \
	neato:${PORTSDIR}/graphics/graphviz \
        swish-e:${PORTSDIR}/www/swish-e \
	${LOCALBASE}/libexec/mysqld:${PORTSDIR}/databases/mysql${MYSQL_VER}-server \
	anytopnm:${PORTSDIR}/graphics/netpbm \
	otclsh:${PORTSDIR}/lang/otcl \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/SNMP.pm:${PORTSDIR}/${P5SNMP_PORT} \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/SNMP_Session.pm:${PORTSDIR}/net-mgmt/p5-SNMP_Session \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Net/Telnet.pm:${PORTSDIR}/net/p5-Net-Telnet \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Net/IP.pm:${PORTSDIR}/net-mgmt/p5-Net-IP \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Math/BigInt.pm:${PORTSDIR}/math/p5-Math-BigInt \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/BSD/Resource.pm:${PORTSDIR}/devel/p5-BSD-Resource \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/Time/HiRes.pm:${PORTSDIR}/devel/p5-Time-HiRes \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/MD5.pm:${PORTSDIR}/security/p5-MD5 \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/Digest/SHA1.pm:${PORTSDIR}/security/p5-Digest-SHA1 \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Expect.pm:${PORTSDIR}/lang/p5-Expect \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/IO/Pty.pm:${PORTSDIR}/devel/p5-IO-Tty \
	rpm:${PORTSDIR}/archivers/rpm4 \
	xvcg:${PORTSDIR}/graphics/vcg \
	${LOCALBASE}/libexec/tftpd:${PORTSDIR}/misc/emulab-tftp-hpa \
	sudo:${PORTSDIR}/security/sudo \
	wget:${PORTSDIR}/ftp/wget \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/XML/Parser:${PORTSDIR}/textproc/p5-XML-Parser \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/RPC/XML.pm:${PORTSDIR}/net/p5-RPC-XML \
	${LOCALBASE}/include/boost:${PORTSDIR}/${BOOST_PORT} \
	gmake:${PORTSDIR}/devel/gmake \
	git:${PORTSDIR}/devel/git \
        curl:${PORTSDIR}/ftp/curl \
	${PYTHON_PKGNAMEPREFIX}MySQLdb>0:${PORTSDIR}/databases/py-MySQLdb \
	mysqlhotcopy:${PORTSDIR}/databases/mysql${MYSQL_VER}-scripts \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/JSON.pm:${PORTSDIR}/converters/p5-JSON

.if (${PORTVERSION} == "5.1" || ${PORTVERSION} == "6.0")
RUN_DEPENDS+=	\
	kmetis:${PORTSDIR}/math/metis4
.else
RUN_DEPENDS+=	\
	kmetis:${PORTSDIR}/math/metis
.endif

# apache related ports
.if (${PORTVERSION} == "4.0" || ${PORTVERSION} == "5.0" || \
     ${PORTVERSION} == "5.1" || ${PORTVERSION} == "6.0")
RUN_DEPENDS+=	\
	${LOCALBASE}/libexec/apache22/mod_ssl.so:${PORTSDIR}/${APACHE_PORT} \
	${LOCALBASE}/libexec/apache22/mod_fastcgi.so:${PORTSDIR}/www/mod_fastcgi
.else
RUN_DEPENDS+=	\
	${LOCALBASE}/etc/apache/ssl.crl:${PORTSDIR}/${APACHE_PORT} \
	mod_auth_mysql>1:${PORTSDIR}/www/mod_auth_mysql
.endif

# m2crypto port
.if ${PORTVERSION} == "6.0"
# the egg is dead, long live the egg!
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}m2crypto>0:${PORTSDIR}/misc/emulab-py-m2crypto-noegg
.elif (${PORTVERSION} == "3.0" || ${PORTVERSION} == "3.1" || \
     ${PORTVERSION} == "4.0" || ${PORTVERSION} == "5.0" || \
     ${PORTVERSION} == "5.1")
# must handle patching of m2crypto when the port is built
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}m2crypto>0:${PORTSDIR}/misc/emulab-py-m2crypto
.else
# for older version we can patch the standard m2crypto once installed
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}m2crypto>0:${PORTSDIR}/security/py-m2crypto
.endif

# dhcpd port
.if (${PORTVERSION} == "4.0" || ${PORTVERSION} == "5.0" || \
     ${PORTVERSION} == "5.1" || ${PORTVERSION} == "6.0")
RUN_DEPENDS+=	\
	dhcpd:${PORTSDIR}/net/isc-dhcp42-server
.elif (${PORTVERSION} == "3.1" || ${PORTVERSION} == "3.0")
RUN_DEPENDS+=	\
	dhcpd:${PORTSDIR}/net/isc-dhcp30-server
.elif ${PORTVERSION} == "2.1"
RUN_DEPENDS+=	\
	dhcpd:${PORTSDIR}/net/isc-dhcp3-server
.endif

# misc. old vs. new port stuff
.if (${PORTVERSION} == "4.0" || ${PORTVERSION} == "5.0" || \
     ${PORTVERSION} == "5.1" || ${PORTVERSION} == "6.0")
RUN_DEPENDS+=	\
	autoconf:${PORTSDIR}/devel/autoconf \
	libtool:${PORTSDIR}/devel/libtool
.else
RUN_DEPENDS+=	\
	autoconf-2.13:${PORTSDIR}/devel/autoconf213
.endif
.if (${PORTVERSION} == "1.7" || ${PORTVERSION} == "2.0")
# for old versions there used to be a problem with newer GD + older perl 
RUN_DEPENDS+=	\
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/GD.pm:${PORTSDIR}/misc/p5-GD-old
.else
RUN_DEPENDS+=	\
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/GD.pm:${PORTSDIR}/graphics/p5-GD \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/XML/Parser.pm:${PORTSDIR}/textproc/p5-XML-Parser \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/RPC/Async.pm:${PORTSDIR}/misc/p5-RPC-Async \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Privileges/Drop.pm:${PORTSDIR}/misc/p5-Privileges-Drop \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/IO/EventMux.pm:${PORTSDIR}/misc/p5-IO-EventMux \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/IO/EventMux/Socket/MsgHdr.pm:${PORTSDIR}/misc/p5-IO-EventMux-Socket-MsgHdr \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Tree/Binary.pm:${PORTSDIR}/devel/p5-Tree-Binary
.if (${PORTVERSION} == "5.0" || ${PORTVERSION} == "5.1" || ${PORTVERSION} == "6.0")
# perl 5.12 and beyond wants this
RUN_DEPENDS+= \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Class/ISA.pm:${PORTSDIR}/devel/p5-Class-ISA
.endif
.endif

.if ${OSMAJOR} >= 10
# bind is no longer part of the base system
RUN_DEPENDS+= \
	${LOCALBASE}/sbin/rndc:${PORTSDIR}/dns/bind99
# include GCC for now to build Emulab SW (assign)
RUN_DEPENDS+= \
	${LOCALBASE}/bin/gcc46:${PORTSDIR}/lang/gcc46
.endif

.if ${OSMAJOR} >= 6
RUN_DEPENDS+= \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/DBI.pm:${PORTSDIR}/databases/p5-DBI \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/XML/Simple.pm:${PORTSDIR}/textproc/p5-XML-Simple \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/XML/LibXML.pm:${PORTSDIR}/textproc/p5-XML-LibXML \
	swig:${PORTSDIR}/devel/swig13 \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Date/Parse.pm:${PORTSDIR}/devel/p5-TimeDate
.else
RUN_DEPENDS+= cvsup:${PORTSDIR}/net/cvsup-without-gui \
	${LOCALBASE}/libexec/apache/libphp${PHP_VER}.so:${PORTSDIR}/www/mod_php${PHP_VER} \
	${LOCALBASE}/include/php/ext/openssl/php_openssl.h:${PORTSDIR}/lang/php${PHP_VER}-extensions \
	${LOCALBASE}/lib/tcl8.4/sql1.0/libTclMySQL.so.1:${PORTSDIR}/databases/tcl-Mysql \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/DBI.pm:${PORTSDIR}/databases/p5-DBI-137 \
	swig1.1:${PORTSDIR}/devel/swig11 \
	${LOCALBASE}/sbin/named:${PORTSDIR}/dns/bind9
.endif

.if ${OSMAJOR} >= 8
RUN_DEPENDS+= \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/LWP/Protocol/https.pm:${PORTSDIR}/www/p5-LWP-Protocol-https
.endif

# make sure these get installed
RUN_DEPENDS+=	\
	${LOCALBASE}/libdata/xorg/libraries:${PORTSDIR}/x11/xorg-libraries \
        ${LOCALBASE}/bin/xauth:${PORTSDIR}/x11/xauth

USE_PERL5=	yes
USE_PYTHON=	yes

NO_BUILD=	yes

do-install:	# empty

NO_STAGE=	yes
.include <bsd.port.mk>

vars:
	@echo "PORTVERSION=$(PORTVERSION)"
	@echo ".MAKEFLAGS=$(.MAKEFLAGS)"
	@echo "BUILD_DEPENDS=$(BUILD_DEPENDS)"
	@echo "LIB_DEPENDS=$(LIB_DEPENDS)"
	@echo "RUN_DEPENDS=$(RUN_DEPENDS)"
	@echo "PERL_VER/ARCH=${PERL_VER}/${PERL_ARCH}"
	@echo "PYTHON_PKGNAMEPREFIX=${PYTHON_PKGNAMEPREFIX}"
