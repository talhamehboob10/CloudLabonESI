# New ports collection makefile for:	emulab-py-m2crypto
# Date created:				06 January 2010
# Whom:					mike@cs.utah.edu
#
# $FreeBSD: ports/security/py-m2crypto/Makefile,v 1.21 2009/01/27 10:20:52 mnag Exp $
#

# Make sure we pick up all the standard port patches too
PATCHDIR=	$(PORTSDIR)/security/py-m2crypto/files

PKGORIGIN=		misc/emulab-py-m2crypto
.include "../../security/py-m2crypto/Makefile"

# Our extra patch
.if ${PORTVERSION} == "0.30.1"
EXTRA_PATCHES=  $(FILESDIR)/emulab-patch-SSL-Connection-30
.else
.if (${PORTVERSION} == "0.29.0" || ${PORTVERSION} == "0.30.1")
EXTRA_PATCHES=  $(FILESDIR)/emulab-patch-SSL-Connection-29
.else
EXTRA_PATCHES=  $(FILESDIR)/emulab-patch-SSL-Connection
.endif
.endif

.if ${PORTVERSION} == "0.25.1"
# Missing dependency for 0.25
RUN_DEPENDS+=   ${PYTHON_PKGNAMEPREFIX}typing>0:${PORTSDIR}/devel/py-typing
.endif

.if !(${PORTVERSION} == "0.22.3" || ${PORTVERSION} == "0.22.5" || ${PORTVERSION} == "0.24.0")
# Fix bug in 0.25.1 and above
EXTRA_PATCHES+= $(FILESDIR)/emulab-patch-httpslib
.endif
