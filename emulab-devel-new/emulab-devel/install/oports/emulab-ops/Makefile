# New ports collection makefile for: emulab-ops
# Date created:         28 January 2003
# Whom:                 ricci@cs.utah.edu

.include "../emulab-boss/Makefile.emulab"

# XXX deal with out-of-sync-edness of original boss/ops ports
.if ${EMULAB_PORTVERSION} == "1.7"
EMULAB_PORTVERSION=	1.4
.endif

PORTNAME=	emulab-ops
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none
COMMENT=	"Meta-port for an Emulab ops node"

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
# For samba, so that it doesn't suck in everything under the sun
#
.MAKEFLAGS+=	-DWITHOUT_WINBIND -DWITHOUT_LDAP -DWITHOUT_POPT -DWITHOUT_CUPS

#
# This prevents any ports from trying to run interactively - some, like the
# net-snmp port, ask silly questions without this option.
#
.MAKEFLAGS+=	-DBATCH

#
# We do this here because we do this for emulab-boss.
#
.MAKEFLAGS+=	WITHOUT_LATEX=yes

#
# XXX not really build dependencies, but these Emulab-specific ports need
# to get installed before any attempt to install the standard versions.
#
.if (${PORTVERSION} == "1.4" || ${PORTVERSION} == "2.0")
BUILD_DEPENDS=	\
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/Mysql.pm:${PORTSDIR}/databases/p5-DBD-mysql${MYSQL_VER}
.elif (${PORTVERSION} == "4.0" || ${PORTVERSION} == "5.0" || \
       ${PORTVERSION} == "5.1" || ${PORTVERSION} == "6.0")
# back to a standard p5-DBD-mysql${MYSQL_VER} install
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

LIB_DEPENDS=

# no linuxthreads on amd64
# old libtool in ulsshxmlrpcpp causes shlibs to be whacked
.if ${OSARCH} == "i386"
.if ${OSMAJOR} < 8
LIB_DEPENDS+= lthread.[236]:${PORTSDIR}/devel/linuxthreads
.endif
LIB_DEPENDS+= ulsshxmlrpcpp.0:${PORTSDIR}/misc/ulsshxmlrpcpp
.endif

.if ${OSMAJOR} >= 6
LIB_DEPENDS+= mhash.2:${PORTSDIR}/security/mhash \
	mysqlclient:${PORTSDIR}/databases/mysql${MYSQL_VER}-client
.endif
.if ${OSMAJOR} >= 7
LIB_DEPENDS+= xmlrpc:${PORTSDIR}/net/xmlrpc-c
.endif

.if defined(ELVIN_COMPAT)
LIB_DEPENDS+= vin4.2:${PORTSDIR}/misc/libelvin \
	pubsub.1:${PORTSDIR}/misc/emulab-pubsub-elvincompat
.else
LIB_DEPENDS+= pubsub.1:${PORTSDIR}/misc/emulab-pubsub
.endif

# We need the BUILD_DEPENDS above to wind up in the dependency list
RUN_DEPENDS:= ${BUILD_DEPENDS}

RUN_DEPENDS+=	\
	gmake:${PORTSDIR}/devel/gmake \
	git:${PORTSDIR}/devel/git \
	sudo:${PORTSDIR}/security/sudo \
	rsync:${PORTSDIR}/net/rsync \
	otclsh:${PORTSDIR}/lang/otcl \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/BSD/Resource.pm:${PORTSDIR}/devel/p5-BSD-Resource \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/Time/HiRes.pm:${PORTSDIR}/devel/p5-Time-HiRes \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/RPC/XML.pm:${PORTSDIR}/net/p5-RPC-XML \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/JSON.pm:${PORTSDIR}/converters/p5-JSON \
	wget:${PORTSDIR}/ftp/wget \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Date/Parse.pm:${PORTSDIR}/devel/p5-TimeDate

.if defined(ELVIN_COMPAT)
RUN_DEPENDS+= ${LOCALBASE}/libexec/elvind:${PORTSDIR}/misc/elvind
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
# also needs swig to install!
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}m2crypto>0:${PORTSDIR}/misc/emulab-py-m2crypto \
	swig:${PORTSDIR}/devel/swig13
.else
# for older version we can patch the standard m2crypto once installed
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}m2crypto>0:${PORTSDIR}/security/py-m2crypto
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

.if ${OSMAJOR} >= 10
# include GCC for now to build Emulab SW (nsverify)
RUN_DEPENDS+= \
	${LOCALBASE}/bin/gcc46:${PORTSDIR}/lang/gcc46
.endif

.if ${OSMAJOR} >= 6
RUN_DEPENDS+= \
	${LOCALBASE}/libexec/mysqld:${PORTSDIR}/databases/mysql${MYSQL_VER}-server \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/DBI.pm:${PORTSDIR}/databases/p5-DBI \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/XML/Parser:${PORTSDIR}/textproc/p5-XML-Parser \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/XML/Simple.pm:${PORTSDIR}/textproc/p5-XML-Simple \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/CGI/Session.pm:${PORTSDIR}/www/p5-CGI-Session \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/GD/Graph.pm:${PORTSDIR}/graphics/p5-GD-Graph \
	${LOCALBASE}/sbin/cvsd:${PORTSDIR}/devel/cvsd \
        ${LOCALBASE}/share/adodb/adodb.inc.php:${PORTSDIR}/databases/adodb \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/HTML/Parser.pm:${PORTSDIR}/www/p5-HTML-Parser \
	${PYTHON_PKGNAMEPREFIX}MySQLdb>0:${PORTSDIR}/databases/py-MySQLdb \
        curl:${PORTSDIR}/ftp/curl \
        snort:${PORTSDIR}/security/snort \
	mysqlhotcopy:${PORTSDIR}/databases/mysql${MYSQL_VER}-scripts \
	${LOCALBASE}/bin/flex:${PORTSDIR}/textproc/flex
.else
RUN_DEPENDS+= smbd:${PORTSDIR}/net/samba3
.endif

# make sure these get installed
RUN_DEPENDS+=	\
	${LOCALBASE}/libdata/xorg/libraries:${PORTSDIR}/x11/xorg-libraries

NO_BUILD=	yes
USE_PYTHON=	yes
USE_PERL5=	yes

do-install:	# empty

NO_STAGE=	yes
.include <bsd.port.mk>
