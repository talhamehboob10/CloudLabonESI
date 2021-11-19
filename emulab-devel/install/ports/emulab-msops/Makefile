# New ports collection makefile for: Mothership emulab-ops
# Date created:         15 June 2015
# Whom:                 testbed-ops@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-msops
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Meta-port for an Emulab Mothership ops node"

# XXX make sure we use md5 routines from libcrypto
misc_mbuffer_SET+=	GCRYPT
misc_mbuffer_UNSET+=	MHASH

#
# This prevents any ports from trying to configure interactively.
#
BATCH=		yes
.MAKEFLAGS+=	BATCH=yes

# Needed
RUN_DEPENDS+=	\
	iocage:${PORTSDIR}/sysutils/iocage \
	bulk_mailer:${PORTSDIR}/mail/bulk_mailer \
	procmail:${PORTSDIR}/mail/procmail \
	syncthing:${PORTSDIR}/net/syncthing \
	telegraf:${PORTSDIR}/net-mgmt/telegraf \
	zfs-stats:${PORTSDIR}/sysutils/zfs-stats \
	bareos-fd:${PORTSDIR}/sysutils/bareos18-client \
	znapzend:${PORTSDIR}/sysutils/znapzend

# Things we like
RUN_DEPENDS+=	\
	ispell:${PORTSDIR}/textproc/aspell-ispell \
	${LOCALBASE}/share/aspell/english.alias:${PORTSDIR}/textproc/en-aspell \
	iftop:${PORTSDIR}/net-mgmt/iftop \
	iperf:${PORTSDIR}/benchmarks/iperf \
	iperf3:${PORTSDIR}/benchmarks/iperf3 \
	nano:${PORTSDIR}/editors/nano \
	nmap:${PORTSDIR}/security/nmap \
	screen:${PORTSDIR}/sysutils/screen \
	smartctl:${PORTSDIR}/sysutils/smartmontools

# Unknown, but sound useful or important
RUN_DEPENDS+=	\
	p5-HTTP-Daemon-SSL>=1.04:${PORTSDIR}/www/p5-HTTP-Daemon-SSL \
	expect:${PORTSDIR}/lang/expect \
	openvpn:${PORTSDIR}/security/openvpn

# Still run mysqld on mothership ops (errorlog)
LIB_DEPENDS=	\
	libmysqlclient.so:${PORTSDIR}/databases/mysql${MYSQL_VER}-client
RUN_DEPENDS+=	\
	${LOCALBASE}/libexec/mysqld:${PORTSDIR}/databases/mysql${MYSQL_VER}-server \
	p5-DBD-mysql>=4.025:${PORTSDIR}/databases/p5-DBD-mysql

# XXX compatibility
RUN_DEPENDS+=	\
	${LOCALBASE}/libdata/ldconfig/compat10x-amd64:${PORTSDIR}/misc/compat10x \
	${LOCALBASE}/libdata/ldconfig/compat11x-amd64:${PORTSDIR}/misc/compat11x \
	/compat/linux/etc/os-release:${PORTSDIR}/emulators/linux_base-c7

USES=		perl5 python:$(PY_VER) php

NO_BUILD=	yes

pre-everything:
	@if ! `pkg info -e emulab-ops`; then \
	    ${ECHO_MSG} "emulab-ops port must be installed first"; \
	    false; \
        fi

do-install:	# empty

.include <bsd.port.mk>
