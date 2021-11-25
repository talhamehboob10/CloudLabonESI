# New ports collection makefile for: emulab-fs
# Date created:         15 June 2015
# Whom:                 testbed-ops@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-fs
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Meta-port for an Emulab fs node"

#
# For samba, so that it doesn't suck in everything under the sun
#
.MAKEFLAGS+=	-DWITHOUT_WINBIND -DWITHOUT_LDAP -DWITHOUT_POPT -DWITHOUT_CUPS -DWITHOUT_IPV6 -DWITHOUT_AVAHI

#
# This prevents any ports from trying to configure interactively.
#
BATCH=		yes
.MAKEFLAGS+=	-DBATCH

# We need the BUILD_DEPENDS above to wind up in the dependency list
RUN_DEPENDS:= ${BUILD_DEPENDS}

RUN_DEPENDS+=	\
	git:${PORTSDIR}/devel/git \
	gmake:${PORTSDIR}/devel/gmake \
	rsync:${PORTSDIR}/net/rsync \
	sudo:${PORTSDIR}/security/sudo

nope_RUN_DEPENDS+= \
	smbd:${PORTSDIR}/net/samba36

NO_BUILD=	yes

do-install:	# empty

.include <bsd.port.mk>
