#
# Emulab version frozen at 0.29.0.
#
# Version 0.30.1 has problems with unicode to string conversions.
# This explicitly caused an exception from the m2crypto SWIG stubs,
# but even after fixing that, we could not verify a certificate due
# to apparent missing chars in strings.
#
# We will resync if/when they fix the problem(s).
#
# Based on:
# Created by: Peter Haight <peterh@sapros.com>
# $FreeBSD: branches/2018Q2/security/py-m2crypto/Makefile 465899 2018-03-29 14:53:23Z mat $

PORTNAME=	m2crypto
PORTVERSION=	0.29.0
PORTREVISION=	1
CATEGORIES=	security python misc
MASTER_SITES=	CHEESESHOP http://www.emulab.net/distributions/
PKGNAMEPREFIX=	${PYTHON_PKGNAMEPREFIX}
DISTNAME=	M2Crypto-${PORTVERSION}

MAINTAINER=	sunpoet@FreeBSD.org
COMMENT=	Crypto and SSL toolkit for Python

LICENSE=	MIT
LICENSE_FILE=	${WRKSRC}/LICENCE

BROKEN_SSL=	openssl-devel
BROKEN_SSL_REASON_openssl-devel=	Error: Syntax error in input(1).

BUILD_DEPENDS=	swig3.0:devel/swig30

PYDISTUTILS_BUILDARGS=	build_ext --include=${OPENSSLINC} --openssl=${OPENSSLBASE} --swig=${LOCALBASE}/bin/swig3.0
USE_PYTHON=	autoplist concurrent distutils
USES=		python ssl

post-patch:
	@${REINPLACE_CMD} -e "s|swig\(', '-version\)|swig3.0\1|" ${WRKSRC}/setup.py

post-install:
	${STRIP_CMD} ${STAGEDIR}${PYTHON_SITELIBDIR}/M2Crypto/_m2crypto.so

.include <bsd.port.pre.mk>

.if ${PYTHON_REL} < 3500
RUN_DEPENDS+=	${PYTHON_PKGNAMEPREFIX}typing>=0:devel/py-typing@${FLAVOR}
.endif

EXTRA_PATCHES=	${FILESDIR}/emulab-patch-SSL-Connection-29 \
		${FILESDIR}/emulab-patch-httpslib

.include <bsd.port.post.mk>
