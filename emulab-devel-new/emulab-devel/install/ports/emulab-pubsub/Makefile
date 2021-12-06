# ports collection makefile for: emulab-pubsub

PORTNAME=	pubsub
PORTVERSION=	0.99
PORTREVISION=	14
CATEGORIES=	misc
MASTER_SITES=	http://www.emulab.net/distributions/
DISTFILES=      ${PORTNAME}-${PORTVERSION}_${PORTREVISION}.tar.gz
WRKSRC=         ${WRKDIR}/${PORTNAME}-${PORTVERSION}_${PORTREVISION}

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Simple publish subscribe system for Emulab"

USE_AUTOTOOLS=	autoconf
GNU_CONFIGURE=	yes
USES=		autoreconf gmake libtool:build,keepla
INSTALLS_SHLIB=	yes

CONFLICTS=	pubsub-elvincompat-[0-9]*
MAKE_FLAGS=	ELVIN_COMPAT= ELVIN_NOELVIN=1

# we seem to be missing a critical dependency to make this work
MAKE_JOBS_UNSAFE=yes

.include <bsd.port.mk>
