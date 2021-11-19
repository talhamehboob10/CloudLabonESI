# New ports collection makefile for: emulab-protogeni
# Date created:         21 July 2009
# Whom:                 stoller@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

# XXX deal with out-of-sync-edness of meta ports
.if ${EMULAB_PORTVERSION} == "6.0"
PORTVERSION=	4.0
.elif ${EMULAB_PORTVERSION} == "5.1"
PORTVERSION=	3.1
.elif ${EMULAB_PORTVERSION} == "5.0"
PORTVERSION=	3.0
.elif ${EMULAB_PORTVERSION} == "4.0"
PORTVERSION=	2.0
.else
PORTVERSION=	1.1
.endif

PORTNAME=	emulab-protogeni
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none
COMMENT=	"Meta-port for a protogeni site"

MAINTAINER=	testbed-ops@flux.utah.edu

.MAKEFLAGS+=	WITH_OPENSSL_BASE=yes

#
# We set this so that the mysql server port doesn't do name resolution
#
.MAKEFLAGS+=	-DSKIP_DNS_CHECK

#
# We must make sure PERL is built with this.
#
.MAKEFLAGS+=	ENABLE_SUIDPERL=yes
.if ${EMULAB_PORTVERSION} == "6.0"
.MAKEFLAGS+=	PERL_VERSION=5.14.4 PERL_VER=5.14 PERL_ARCH=mach
.elif ${EMULAB_PORTVERSION} == "5.1"
.MAKEFLAGS+=	PERL_VERSION=5.12.5 PERL_VER=5.12 PERL_ARCH=mach
.elif ${EMULAB_PORTVERSION} == "5.0"
.MAKEFLAGS+=	PERL_VERSION=5.12.4 PERL_VER=5.12.4 PERL_ARCH=mach
.elif (${EMULAB_PORTVERSION} == "3.1" || ${EMULAB_PORTVERSION} == "4.0")
.MAKEFLAGS+=	PERL_VERSION=5.10.1 PERL_VER=5.10.1 PERL_ARCH=mach
.elif ${EMULAB_PORTVERSION} == "3.0"
.MAKEFLAGS+=	PERL_VERSION=5.10.0 PERL_VER=5.10.0 PERL_ARCH=mach
.endif

#
# For SWIG, so that it doesn't feel the need to suck in php and apache
# XXX Something is broken on FreeBSD 6.X and SWIG_LANGUAGES='x y z' breaks.
#
.MAKEFLAGS+=	SWIG_LANGUAGES= 
.MAKEFLAGS+=    WANT_SWIG_PERL=yes WANT_SWIG_PYTHON=yes WANT_SWIG_TCL=yes

#
# Various ports need to agree on what version of apache. Make sure this
# agrees with what is in the emulab-ops and emulab-php4 metaports.
#
.if ${PORTVERSION} != "1.1"
.MAKEFLAGS+=	APACHE_PORT=www/apache22
.else
.MAKEFLAGS+=	APACHE_PORT=www/apache13-modssl
.endif

#
# This prevents any ports from trying to run interactively - some, like the
# net-snmp port, ask silly questions without this option.
#
.MAKEFLAGS+=	-DBATCH

LIB_DEPENDS= xml2.5:${PORTSDIR}/textproc/libxml2

RUN_DEPENDS+= \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/Crypt/SSLeay.pm:${PORTSDIR}/security/p5-Crypt-SSLeay \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/XML/LibXML.pm:${PORTSDIR}/textproc/p5-XML-LibXML \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Frontier/Client.pm:${PORTSDIR}/net/p5-Frontier-RPC \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Convert/ASN1.pm:${PORTSDIR}/converters/p5-Convert-ASN1 \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/Crypt/X509.pm:${PORTSDIR}/security/p5-Crypt-X509 \
	${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/Crypt/OpenSSL/X509.pm:${PORTSDIR}/security/p5-Crypt-OpenSSL-X509 \
${LOCALBASE}/lib/perl5/site_perl/${PERL_VER}/XML/SemanticDiff.pm:${PORTSDIR}/textproc/p5-XML-SemanticDiff \
	xmlsec1:${PORTSDIR}/security/xmlsec1 \
	${LOCALBASE}/libexec/apache22/mod_wsgi.so:${PORTSDIR}/www/mod_wsgi3 \
	${PYTHON_PKGNAMEPREFIX}flask:${PORTSDIR}/www/py-flask

USE_PERL5=	yes
USE_PYTHON=	yes

NO_BUILD=	yes

do-install:	# empty

NO_STAGE=	yes
.include <bsd.port.mk>
