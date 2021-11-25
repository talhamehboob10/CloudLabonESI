# New ports collection makefile for: emulab-ops
# Date created:         15 June 2015
# Whom:                 testbed-ops@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-ops
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Meta-port for an Emulab ops node"

#
# For PHP, specify that we want the Apache module.
#
WANT_PHP_MOD=	yes

#
# PHP modules to build.
#
USE_PHP=	bz2 ctype curl dom filter gd hash iconv json mcrypt \
		openssl pdo phar posix session simplexml sockets tokenizer \
		xml xmlreader xmlrpc xmlwriter

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

LIB_DEPENDS=	\
	libmhash.so:${PORTSDIR}/security/mhash \
	libxmlrpc.so:${PORTSDIR}/net/xmlrpc-c \
	libpubsub.so:${PORTSDIR}/misc/emulab-pubsub

# We need the BUILD_DEPENDS above to wind up in the dependency list
RUN_DEPENDS:= ${BUILD_DEPENDS}

#
# Emulab-hacked versions of standard ports
#
.if (${EMULAB_PORTVERSION} != "7.3" && ${EMULAB_PORTVERSION} != "8.2")
RUN_DEPENDS+=	\
	${PTYHON_PKGNAMEPREFIX}m2crypto>0:${PORTSDIR}/misc/emulab-py-m2crypto
.endif

# compensate for incomplete dependencies (boehm-gc via git)
RUN_DEPENDS+=	\
	pkgconf:${PORTSDIR}/devel/pkgconf

# apps
RUN_DEPENDS+=	\
	autoconf:${PORTSDIR}/devel/autoconf \
	curl:${PORTSDIR}/ftp/curl \
	git:${PORTSDIR}/devel/git \
	gmake:${PORTSDIR}/devel/gmake \
	libtool:${PORTSDIR}/devel/libtool \
	otclsh:${PORTSDIR}/misc/otcl \
	rsync:${PORTSDIR}/net/rsync \
	sudo:${PORTSDIR}/security/sudo \
	wget:${PORTSDIR}/ftp/wget \
	${LOCALBASE}/bin/flex:${PORTSDIR}/textproc/flex

# perl packages
# XXX all the versions listed here are ones that are known to work
#     on a 10.0 system.
#
RUN_DEPENDS+=	\
	p5-BSD-Resource>=1.2907:${PORTSDIR}/devel/p5-BSD-Resource \
	p5-CGI>=4.13:${PORTSDIR}/www/p5-CGI \
	p5-CGI-Session>=4.48:${PORTSDIR}/www/p5-CGI-Session \
	p5-DBI>=1.630:${PORTSDIR}/databases/p5-DBI \
	p5-GD-Graph>=1.48:${PORTSDIR}/graphics/p5-GD-Graph \
	p5-HTML-Parser>=3.71:${PORTSDIR}/www/p5-HTML-Parser \
	p5-JSON>=2.61:${PORTSDIR}/converters/p5-JSON \
	p5-RPC-XML>=0.77:${PORTSDIR}/net/p5-RPC-XML \
	p5-Time-HiRes>=1.9726:${PORTSDIR}/devel/p5-Time-HiRes \
	p5-TimeDate>=2.30:${PORTSDIR}/devel/p5-TimeDate \
	p5-XML-Parser>=2.41:${PORTSDIR}/textproc/p5-XML-Parser \
	p5-XML-Simple>=2.20:${PORTSDIR}/textproc/p5-XML-Simple \
	p5-Digest-SHA1>=2.13:${PORTSDIR}/security/p5-Digest-SHA1 \
	p5-Digest-HMAC>=1.03:${PORTSDIR}/security/p5-Digest-HMAC

# python packages
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}dateutil>0:${PORTSDIR}/devel/py-dateutil \
	${PYTHON_PKGNAMEPREFIX}cryptography>0:${PORTSDIR}/security/py-cryptography \
	${PYTHON_PKGNAMEPREFIX}lxml>0:${PORTSDIR}/devel/py-lxml

.if (${EMULAB_PORTVERSION} == "7.3" || ${EMULAB_PORTVERSION} == "8.2")
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}certbot>0:${PORTSDIR}/security/py-certbot \
	${PYTHON_PKGNAMEPREFIX}tornado>0:${PORTSDIR}/www/py-tornado \
	${PYTHON_PKGNAMEPREFIX}paramiko>0:${PORTSDIR}/security/py-paramiko
.endif

# apache related ports
RUN_DEPENDS+=	\
	${LOCALBASE}/${APACHEMODDIR}/mod_ssl.so:${PORTSDIR}/${APACHE_PORT} \
	${LOCALBASE}/${APACHEMODDIR}/libphp$(PHP_MAJ).so:${PORTSDIR}/www/mod_php$(PHP_VER)

# PHP packages
RUN_DEPENDS+= \
        ${LOCALBASE}/share/adodb/adodb.inc.php:${PORTSDIR}/databases/adodb

# Alternative shells that we allow users to select
RUN_DEPENDS+= \
        bash:${PORTSDIR}/shells/bash \
        zsh:${PORTSDIR}/shells/zsh

# For reasons lost in the mists of time, we install this
RUN_DEPENDS+=	\
	${LOCALBASE}/libdata/pkgconfig/x11.pc:${PORTSDIR}/x11/xorg-libraries

#USE_PERL5=	yes
USES=		perl5 python:$(PY_VER) php

NO_BUILD=	yes

do-install:	# empty

.include <bsd.port.mk>
