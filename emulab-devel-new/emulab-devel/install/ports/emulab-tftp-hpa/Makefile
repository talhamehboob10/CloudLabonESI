# New ports collection makefile for:	tftpd-hpa (emulab version)
# Date created:		4 February 2003
# Whom:			mike@cs.utah.edu
#
# $FreeBSD$
#

PORTNAME=	tftp-hpa
PORTVERSION=	5.2
PORTREVISION=	3
#CATEGORIES=	net
CATEGORIES=	misc
MASTER_SITES=	http://www.emulab.net/distributions/
PKGNAMEPREFIX=	emulab-
DISTNAME=	${PORTNAME}-${PORTVERSION}

MAINTAINER=	mike@cs.utah.edu
COMMENT=	"The tftpd-hpa TFTP distribution as configured for Emulab"

PATCH_STRIP=	-p1

GNU_CONFIGURE=	YES
USES=		gmake

DESTDIRNAME=	INSTALLROOT

# for now only install the daemon
INSTALL_WRKSRC=	${WRKSRC}/tftpd

# make sure we don't run configure (with no args) out of the Makefile
# due to our patching configure.in
post-patch:
	touch ${WRKSRC}/aconfig.h.in ${WRKSRC}/configure

post-install:
	@${ECHO} ""
	@${ECHO} "      ${PREFIX}/etc/rc.d/tftpd-hpa.sh startup file has been installed."
	@${ECHO} "      Configure startup flags with \"tfpd_flags\" in /etc/rc.conf."
	@${ECHO} "      Don't forget to disable tftpd in /etc/inetd.conf!"
	@${ECHO} ""

.include <bsd.port.mk>
