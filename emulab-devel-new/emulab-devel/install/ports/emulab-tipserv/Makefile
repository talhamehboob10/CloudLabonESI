# ports collection makefile for: emulab-tipserv
# Date created:         15 June 2015
# Whom:                 testbed-ops@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-tipserv
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Meta-port for an Emulab tipserv node"

NO_BUILD=	yes

#
# This prevents any ports from trying to configure interactively.
#
BATCH=		yes
.MAKEFLAGS+=	-DBATCH

LIB_DEPENDS=	\
	libtelnet.so:${PORTSDIR}/misc/libtelnet

RUN_DEPENDS=	\
	git:${PORTSDIR}/devel/git \
	gmake:${PORTSDIR}/devel/gmake \
        netcat:${PORTSDIR}/net/netcat \
	sudo:${PORTSDIR}/security/sudo \
	ipmitool:${PORTSDIR}/sysutils/ipmitool

do-install:	# empty

.include <bsd.port.mk>
