# New ports collection makefile for: Mothership emulab-boss
# Date created:         15 June 2015
# Whom:                 testbed-ops@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-msboss
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Meta-port for an Emulab Mothership boss node"

#
# This prevents any ports from trying to configure interactively.
#
BATCH=		yes
.MAKEFLAGS+=	BATCH=yes

# Needed
RUN_DEPENDS+=	\
	ansible:${PORTSDIR}/sysutils/ansible \
	gnuplot:${PORTSDIR}/math/gnuplot-emulab \
	racket:${PORTSDIR}/lang/racket \
	syncthing:${PORTSDIR}/net/syncthing \
	telegraf:${PORTSDIR}/net-mgmt/telegraf \
	bareos-fd:${PORTSDIR}/sysutils/bareos18-client

# Things we like
RUN_DEPENDS+=	\
	fio:${PORTSDIR}/benchmarks/fio \
	fping:${PORTSDIR}/net/fping \
	iftop:${PORTSDIR}/net-mgmt/iftop \
	iperf:${PORTSDIR}/benchmarks/iperf \
	iperf3:${PORTSDIR}/benchmarks/iperf3 \
	nano:${PORTSDIR}/editors/nano \
	nmap:${PORTSDIR}/security/nmap \
	smartctl:${PORTSDIR}/sysutils/smartmontools \
	valgrind:${PORTSDIR}/devel/valgrind \
	zip:${PORTSDIR}/archivers/zip \

# For Leigh
RUN_DEPENDS+=	\
	autocutsel:${PORTSDIR}/deskutils/autocutsel \
	vncserver:${PORTSDIR}/net/tigervnc-server \
	xorg-fonts>=7.2:${PORTSDIR}/x11-fonts/xorg-fonts \
	fvwm:${PORTSDIR}/x11-wm/fvwm2 \
	xdpyinfo:${PORTSDIR}/x11/xdpyinfo \
	xfontsel:${PORTSDIR}/x11-fonts/xfontsel \
	xrdb:${PORTSDIR}/x11/xrdb \
	xset:${PORTSDIR}/x11/xset \
	xsetroot:${PORTSDIR}/x11/xsetroot

# Unknown, but sound useful or important
RUN_DEPENDS+=	\
	p5-Devel-Leak-Object>=1.01:${PORTSDIR}/devel/p5-Devel-Leak-Object \
	p5-Devel-Size>=0.82:${PORTSDIR}/devel/p5-Devel-Size \
	p5-HTTP-Daemon-SSL>=1.04:${PORTSDIR}/www/p5-HTTP-Daemon-SSL \
	p5-Text-CSV>=1.97:${PORTSDIR}/textproc/p5-Text-CSV \
	p5-URI-Encode>=0.09:${PORTSDIR}/www/p5-URI-Encode \
	p5-WWW-Curl>=4.17:${PORTSDIR}/www/p5-WWW-Curl \
	p5-XML-Entities>=1.002:${PORTSDIR}/textproc/p5-XML-Entities \
	${PYTHON_PKGNAMEPREFIX}ecdsa>=0.11:${PORTSDIR}/security/py-ecdsa \
	${PYTHON_PKGNAMEPREFIX}pyjwt>=1.4.0:${PORTSDIR}/www/py-pyjwt

# XXX for old binaries
RUN_DEPENDS+=	\
	${LOCALBASE}/libdata/ldconfig/compat10x-amd64:${PORTSDIR}/misc/compat10x \
	${LOCALBASE}/libdata/ldconfig/compat11x-amd64:${PORTSDIR}/misc/compat11x

USES=		perl5 python:$(PY_VER) php

NO_BUILD=	yes

pre-everything:
	@if ! `pkg info -e emulab-boss`; then \
	    ${ECHO_MSG} "emulab-boss port must be installed first"; \
	    false; \
        fi

do-install:	# empty

.include <bsd.port.mk>

vars:
	@echo "PORTVERSION=$(PORTVERSION)"
	@echo ".MAKEFLAGS=$(.MAKEFLAGS)"
	@echo "BUILD_DEPENDS=$(BUILD_DEPENDS)"
	@echo "LIB_DEPENDS=$(LIB_DEPENDS)"
	@echo "RUN_DEPENDS=$(RUN_DEPENDS)"
	@echo "PYTHON_PKGNAMEPREFIX=${PYTHON_PKGNAMEPREFIX}"
	@echo "MYSQL_VER=${MYSQL_VER}"
	@echo "APACHE_PORT/VERSION=${APACHE_PORT}/${APACHE_VERSION}"
	@echo "USE_APACHE/USE_APACHE_BUILD/USE_APACHE_RUN=${USE_APACHE}/${USE_APACHE_BUILD}/${USE_APACHE_RUN}"
	@echo "USE_PHP=${USE_PHP}"
	@echo "USES=${USES}"
