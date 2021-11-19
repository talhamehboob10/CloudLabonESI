# New ports collection makefile for: emulab-mailman
# Date created:         23 February 2006
# Whom:                 stoller@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

#
# We happen to run the web server as "nobody"
#
CGI_GID=	nobody
WITH_SENDMAIL=	yes

#
# This prevents the option screen.
#
BATCH=yes

#
# But need this too!
#
.MAKEFLAGS+=	-DBATCH CGI_GID=nobody

#
# We must make sure PERL is built with these.
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

MASTERDIR=	${.CURDIR}/../../mail/mailman

.include "${MASTERDIR}/Makefile"
