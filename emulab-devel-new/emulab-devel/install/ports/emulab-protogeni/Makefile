# New ports collection makefile for: emulab-protogeni
# Date created:         15 June 2015
# Whom:                 testbed-ops@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-protogeni
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Meta-port for a protogeni site"

#
# For PHP, specify that we want the Apache module.
#
WANT_PHP_MOD=	yes

#
# Various ports need to agree on what version of apache.
#
www_apache24_SET=	SUEXEC
.MAKEFLAGS+=	APACHE_PORT=www/apache24
.MAKEFLAGS+=	WITH_SUEXEC=yes

#
# This prevents any ports from trying to run interactively - some, like the
# net-snmp port, ask silly questions without this option.
#
BATCH=		yes
.MAKEFLAGS+=	BATCH=yes

LIB_DEPENDS=	\
	libabac.so:${PORTSDIR}/misc/abac \
	libxml2.so:${PORTSDIR}/textproc/libxml2

# apps
RUN_DEPENDS+=	\
	xmlsec1:${PORTSDIR}/security/xmlsec1

# perl packages
# XXX all the versions listed here are ones that are known to work
#     on a 10.0 system.
#
RUN_DEPENDS+= \
	p5-Crypt-SSLeay>=0.72:${PORTSDIR}/security/p5-Crypt-SSLeay \
	p5-XML-LibXML>=2.0107:${PORTSDIR}/textproc/p5-XML-LibXML \
	p5-Frontier-RPC>0:${PORTSDIR}/net/p5-Frontier-RPC \
	p5-Convert-ASN1>=0.26:${PORTSDIR}/converters/p5-Convert-ASN1 \
	p5-Crypt-X509>=0.51:${PORTSDIR}/security/p5-Crypt-X509 \
	p5-Crypt-OpenSSL-X509>=1.8.04:${PORTSDIR}/security/p5-Crypt-OpenSSL-X509 \
	p5-XML-SemanticDiff>=1.0002:${PORTSDIR}/textproc/p5-XML-SemanticDiff

# python packages
RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}Flask>=0.10:${PORTSDIR}/www/py-flask

# apache related ports
RUN_DEPENDS+=	\
	${LOCALBASE}/${APACHEMODDIR}/mod_wsgi.so:${PORTSDIR}/www/mod_wsgi4 \
	${LOCALBASE}/${APACHEMODDIR}/mod_fcgid.so:${PORTSDIR}/www/mod_fcgid \
	p5-FCGI>=0.74:${PORTSDIR}/www/p5-FCGI

#USE_PERL5=	yes
USES=		perl5 python:$(PY_VER) php

NO_BUILD=	yes

do-install:	# empty

.include <bsd.port.mk>
