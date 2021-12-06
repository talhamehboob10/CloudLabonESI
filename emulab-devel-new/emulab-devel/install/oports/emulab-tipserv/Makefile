#
# New ports collection makefile for: emulab-tipserv
#

.include "../emulab-boss/Makefile.emulab"

# XXX deal with out-of-sync-edness of original boss/ops ports
.if ${EMULAB_PORTVERSION} == "1.7"
EMULAB_PORTVERSION=	1.4
.endif

PORTNAME=	emulab-tipserv
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none
COMMENT=	"Meta-port for an Emulab tipserv node"

MAINTAINER=	testbed-ops@flux.utah.edu

#
# We must make sure PERL is built with these.
#
.MAKEFLAGS+=	ENABLE_SUIDPERL=yes
.if ${PORTVERSION} == "6.0"
.MAKEFLAGS+=	PERL_VERSION=5.14.4 PERL_VER=5.14 PERL_ARCH=mach
.elif ${PORTVERSION} == "5.1"
.MAKEFLAGS+=	PERL_VERSION=5.12.5 PERL_VER=5.12 PERL_ARCH=mach
.elif ${PORTVERSION} == "5.0"
.MAKEFLAGS+=	PERL_VERSION=5.12.4 PERL_VER=5.12.4 PERL_ARCH=mach
.elif (${PORTVERSION} == "3.1" || ${PORTVERSION} == "4.0")
.MAKEFLAGS+=	PERL_VERSION=5.10.1 PERL_VER=5.10.1 PERL_ARCH=mach
.elif ${PORTVERSION} == "3.0"
.MAKEFLAGS+=	PERL_VERSION=5.10.0 PERL_VER=5.10.0 PERL_ARCH=mach
.endif

#
# This prevents any ports from trying to run interactively - some, like the
# net-snmp port, ask silly questions without this option.
#
.MAKEFLAGS+=	-DBATCH

#
# We do this here because we do this for emulab-boss.
#
.MAKEFLAGS+=	WITHOUT_LATEX=yes

BUILD_DEPENDS=

LIB_DEPENDS=	\
	telnet.2:${PORTSDIR}/misc/libtelnet

# We need the BUILD_DEPENDS above to wind up in the dependency list
RUN_DEPENDS:= ${BUILD_DEPENDS}

RUN_DEPENDS+=	\
	sudo:${PORTSDIR}/security/sudo

NO_BUILD=	yes

do-install:	# empty

NO_STAGE=	yes
.include <bsd.port.mk>
