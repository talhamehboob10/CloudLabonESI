# ports collection makefile for: emulab-genilib
# Date created:         05 July 2016
# Whom:                 testbed-ops@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-genilib
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Meta-port for an Emulab geni-lib jail"

#
# This prevents any ports from trying to configure interactively.
#
BATCH=		yes
.MAKEFLAGS+=	-DBATCH

RUN_DEPENDS=	\
	${PYTHON_PKGNAMEPREFIX}cryptography>0:${PORTSDIR}/security/py-cryptography \
	${PYTHON_PKGNAMEPREFIX}lxml>0:${PORTSDIR}/devel/py-lxml

USES=		python:$(PY_VER)

NO_BUILD=	yes

do-install:	# empty

.include <bsd.port.mk>
