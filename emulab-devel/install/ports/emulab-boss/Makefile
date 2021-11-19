# New ports collection makefile for: emulab-boss
# Date created:         15 June 2015
# Whom:                 testbed-ops@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-boss
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Meta-port for an Emulab boss node"

# XXX old 2.8.0 xerces-c until we get assign converted
#XERCES_PORT=	textproc/xerces-c3
XERCES_PORT=	misc/xerces-c2

#
# For PHP, specify that we want the Apache module.
#
WANT_PHP_MOD=	yes

#
# PHP modules to build.
# XXX based on current boss install.
#
.if (${EMULAB_PORTVERSION} == "7.3" || ${EMULAB_PORTVERSION} == "8.2")
USE_PHP=	bz2 ctype curl dom filter gd hash iconv json mcrypt mysqli \
		openssl pdo phar posix session simplexml sockets tokenizer \
		xml xmlreader xmlrpc xmlwriter
.else
USE_PHP=	bz2 ctype curl dom filter gd hash iconv json mcrypt mysql \
		openssl pdo phar posix session simplexml sockets tokenizer \
		xml xmlreader xmlrpc xmlwriter
.endif

#
# Various ports need to agree on what version of apache.
#
www_apache24_SET=	SUEXEC
.MAKEFLAGS+=	APACHE_PORT=www/apache24
.MAKEFLAGS+=	WITH_SUEXEC=yes

#
# This prevents any ports from trying to configure interactively.
#
BATCH=		yes
.MAKEFLAGS+=	BATCH=yes

LIB_DEPENDS= libgd.so:${PORTSDIR}/graphics/gd \
	libmhash.so:${PORTSDIR}/security/mhash \
	libmysqlclient.so:${PORTSDIR}/databases/mysql${MYSQL_VER}-client \
	libnetsnmp.so:${PORTSDIR}/net-mgmt/net-snmp \
	libxerces-c.so:${PORTSDIR}/${XERCES_PORT} \
	libxmlrpc.so:${PORTSDIR}/net/xmlrpc-c \
	libpubsub.so:${PORTSDIR}/misc/emulab-pubsub

# We need the BUILD_DEPENDS above to wind up in the dependency list
RUN_DEPENDS:= ${BUILD_DEPENDS}

#
# XXX hackary to get around bugs in Makefiles:
#
# Both pango (required by graphviz) and gtk-update-icon-cache (required by
# emacs) perform a Makefile (pre-configure target) existence check using
# ".if exists" for the cairo port. However, since that check is done at
# Makefile parse time, the things they are checking for might not yet be
# installed. Instead those items get installed as a result of the dependencies
# in the Makefile. The Makefiles should really be changed to make run-time
# check (i.e., a shell "test" command) for the existence of packages that
# they might install.
#
RUN_DEPENDS+=	\
	${LOCALBASE}/libdata/pkgconfig/cairo-gobject.pc:${PORTSDIR}/graphics/cairo

#
# Emulab-hacked versions of standard ports
#
RUN_DEPENDS+=	\
	${LOCALBASE}/libexec/tftpd:${PORTSDIR}/misc/emulab-tftp-hpa
.if (${EMULAB_PORTVERSION} != "7.3" && ${EMULAB_PORTVERSION} != "8.2")
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}m2crypto>0:${PORTSDIR}/misc/emulab-py-m2crypto
.endif

# apps
RUN_DEPENDS+=	\
	anytopnm:${PORTSDIR}/graphics/netpbm \
	autoconf>=2.69:${PORTSDIR}/devel/autoconf \
	curl:${PORTSDIR}/ftp/curl \
	git:${PORTSDIR}/devel/git \
	gmake:${PORTSDIR}/devel/gmake \
	hg:${PORTSDIR}/devel/mercurial \
	ipmitool:${PORTSDIR}/sysutils/ipmitool \
	libtool:${PORTSDIR}/devel/libtool \
	neato:${PORTSDIR}/graphics/graphviz \
	otclsh:${PORTSDIR}/misc/otcl \
	pssh:${PORTSDIR}/security/pssh \
	rpm:${PORTSDIR}/archivers/rpm4 \
	rrdtool:${PORTSDIR}/databases/rrdtool \
	rsync:${PORTSDIR}/net/rsync \
	swig${SWIG_VER}:${PORTSDIR}/${SWIG_PORT} \
	sudo:${PORTSDIR}/security/sudo \
	medusa:${PORTSDIR}/misc/emulab-medusa \
	nmap:${PORTSDIR}/security/nmap \
	wget:${PORTSDIR}/ftp/wget \
	xvcg:${PORTSDIR}/graphics/vcg \
	${LOCALBASE}/libexec/mysqld:${PORTSDIR}/databases/mysql${MYSQL_VER}-server \
	${LOCALBASE}/include/boost/config.hpp:${PORTSDIR}/devel/boost-all

#
# Metis version changed
.if (${EMULAB_PORTVERSION} == "7.3" || ${EMULAB_PORTVERSION} == "8.2")
RUN_DEPENDS+=	\
	gpmetis:${PORTSDIR}/math/metis
.else
RUN_DEPENDS+=	\
	kmetis:${PORTSDIR}/math/metis4
.endif


# perl packages
# XXX all the versions listed here are ones that are known to work
#     on a 10.0 system.
#
RUN_DEPENDS+=	\
	p5-BSD-Resource>=1.2907:${PORTSDIR}/devel/p5-BSD-Resource \
	p5-CGI>=4.13:${PORTSDIR}/www/p5-CGI \
	p5-Class-ISA>=0.36:${PORTSDIR}/devel/p5-Class-ISA \
	p5-DBD-mysql>=4.025:${PORTSDIR}/databases/p5-DBD-mysql \
	p5-DBI>=1.630:${PORTSDIR}/databases/p5-DBI \
	p5-Digest-SHA1>=2.13:${PORTSDIR}/security/p5-Digest-SHA1 \
	p5-Expect>=1.21:${PORTSDIR}/lang/p5-Expect \
	p5-GD>=2.50:${PORTSDIR}/graphics/p5-GD \
	p5-IO-EventMux>=2.02:${PORTSDIR}/misc/p5-IO-EventMux \
	p5-IO-EventMux-Socket-MsgHdr>=0.02:${PORTSDIR}/misc/p5-IO-EventMux-Socket-MsgHdr \
	p5-IO-Tty>=1.10:${PORTSDIR}/devel/p5-IO-Tty \
	p5-JSON>=2.61:${PORTSDIR}/converters/p5-JSON \
	p5-LWP-Protocol-https>=6.04:${PORTSDIR}/www/p5-LWP-Protocol-https \
	p5-Math-BigInt>=1.997:${PORTSDIR}/math/p5-Math-BigInt \
	p5-MD5>=2.03:${PORTSDIR}/security/p5-MD5 \
	p5-Net-Telnet>=3.04:${PORTSDIR}/net/p5-Net-Telnet \
	p5-Net-IP>=1.26:${PORTSDIR}/net-mgmt/p5-Net-IP \
	p5-Privileges-Drop>=1.01:${PORTSDIR}/misc/p5-Privileges-Drop \
	p5-RPC-Async>=1.05:${PORTSDIR}/misc/p5-RPC-Async \
	p5-RPC-XML>=0.77:${PORTSDIR}/net/p5-RPC-XML \
	p5-SNMP_Session>=1.13:${PORTSDIR}/net-mgmt/p5-SNMP_Session \
	p5-Time-HiRes>=1.9726:${PORTSDIR}/devel/p5-Time-HiRes \
	p5-TimeDate>=2.30:${PORTSDIR}/devel/p5-TimeDate \
	p5-Tree-Binary>=1.05:${PORTSDIR}/devel/p5-Tree-Binary \
	p5-XML-LibXML>=2.0107:${PORTSDIR}/textproc/p5-XML-LibXML \
	p5-XML-Parser>=2.41:${PORTSDIR}/textproc/p5-XML-Parser \
	p5-XML-Simple>=2.20:${PORTSDIR}/textproc/p5-XML-Simple \
        p5-RRDTool-OO>=0.36:${PORTSDIR}/devel/p5-RRDTool-OO

# python packages
.if (${EMULAB_PORTVERSION} == "8.2")
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}mysqlclient>0:${PORTSDIR}/databases/py-mysqlclient
.else
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}MySQLdb>0:${PORTSDIR}/databases/py-MySQLdb
.endif
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}dateutil>0:${PORTSDIR}/devel/py-dateutil \
	${PYTHON_PKGNAMEPREFIX}cryptography>0:${PORTSDIR}/security/py-cryptography \
	${PYTHON_PKGNAMEPREFIX}lxml>0:${PORTSDIR}/devel/py-lxml

.if (${EMULAB_PORTVERSION} == "7.3" || ${EMULAB_PORTVERSION} == "8.2")
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}certbot>0:${PORTSDIR}/security/py-certbot
.endif

# apache related ports
RUN_DEPENDS+=	\
	${LOCALBASE}/${APACHEMODDIR}/mod_ssl.so:${PORTSDIR}/${APACHE_PORT} \
	${LOCALBASE}/${APACHEMODDIR}/libphp$(PHP_MAJ).so:${PORTSDIR}/www/mod_php$(PHP_VER) \
	${LOCALBASE}/${APACHEMODDIR}/mod_fcgid.so:${PORTSDIR}/www/mod_fcgid

# Port versions of current or former "core" utilties
RUN_DEPENDS+=	\
	dhcpd:${PORTSDIR}/net/isc-dhcp44-server \
	${LOCALBASE}/sbin/rndc:${PORTSDIR}/dns/bind911

.if (${EMULAB_PORTVERSION} == "7.3" || ${EMULAB_PORTVERSION} == "8.2")
# dig and friends
RUN_DEPENDS+=	\
	${LOCALBASE}/bin/dig:${PORTSDIR}/dns/bind-tools
.endif

# XXX For building loghole doc from www/tutorial
RUN_DEPENDS+=	\
	man2html:${PORTSDIR}/textproc/man2html

# XXX For Powder end point boss nodes, maybe they should have their own port
RUN_DEPENDS+= \
	syncthing:${PORTSDIR}/net/syncthing

#USE_PERL5=	yes
USES=		perl5 python:$(PY_VER) php

NO_BUILD=	yes

do-install:	# empty

.include <bsd.port.mk>

vars:
	@echo "PORTVERSION=$(PORTVERSION)"
	@echo ".MAKEFLAGS=$(.MAKEFLAGS)"
	@echo "BUILD_DEPENDS=$(BUILD_DEPENDS)"
	@echo "LIB_DEPENDS=$(LIB_DEPENDS)"
	@echo "RUN_DEPENDS=$(RUN_DEPENDS)"
	@echo "PYTHON_PKGNAMEPREFIX=${PYTHON_PKGNAMEPREFIX}"
	@echo "MYSQL_VER=${MYSQL_VER}"
	@echo "APACHE_PORT/VERSION=${APACHE_PORT}/${APACHE_VERSION}"
	@echo "USE_APACHE/USE_APACHE_BUILD/USE_APACHE_RUN=${USE_APACHE}/${USE_APACHE_BUILD}/${USE_APACHE_RUN}"
	@echo "USE_PHP=${USE_PHP}"
	@echo "USES=${USES}"
