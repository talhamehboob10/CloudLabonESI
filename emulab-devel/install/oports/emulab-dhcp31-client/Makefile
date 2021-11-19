#
# XXX hacked up Emulab version of isc-dhcp30-server/Makefile to be standalone
# for dhcp30-client. We have no local mods to this version of dhcp, we just
# need a dhclient program that works on multiple interfaces at once, hence we
# keep this version alive.
# From:
#
# ex:ts=8
# Ports collection makefile for:    dhcp
# Date created:         7 Mar 1996
# Whom:                 se
#
# $FreeBSD: ports/net/isc-dhcp31-server/Makefile,v 1.133 2010/10/14 15:45:39 jpaetzel Exp $
#

PORTNAME=	dhcp
PORTVERSION=	3.1.ESV
PORTEPOCH=	1
PORTREVISION=	${DHCP_PORTREVISION}
CATEGORIES=	misc net
MASTER_SITES=	${MASTER_SITE_ISC}
MASTER_SITE_SUBDIR=	dhcp dhcp/dhcp-3.1-history
PKGNAMEPREFIX=	isc-
PKGNAMESUFFIX=	31-client
DISTNAME=	${PORTNAME}-3.1-ESV

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT?=	The old ISC 3.1 DHCP client for Emulab

PORTREVISION_SERVER=	0
PORTREVISION_CLIENT=	0
PORTREVISION_RELAY=	0
PORTREVISION_DEVEL=	0

UNIQUENAME=	${PKGNAMEPREFIX}${PORTNAME}${PKGNAMESUFFIX}

# PORTREVISION handling
DHCP_PORTREVISION=	${PORTREVISION_CLIENT}

NO_STAGE=	yes
.include <bsd.port.pre.mk>

# Global variables
#

HAS_CONFIGURE=	yes
CONFIGURE_ARGS=	--subsys client
ALL_TARGET=	all.client
INSTALL_TARGET=	install.client
SCRIPTS_ENV+=	PKG_PREFIX=${PREFIX}

MAN5=		dhclient.conf.5 dhclient.leases.5
MAN8=		dhclient.8 dhclient-script.8
MAN5+=		dhcp-eval.5 dhcp-options.5

MSG_FILE=	${.CURDIR}/pkg-message
DESCR=		${.CURDIR}/pkg-descr
PKGMESSAGE=	${WRKDIR}/pkg-message
PLIST=		${.CURDIR}/pkg-plist

PATCH_SUBDIRS=	common minires dst omapip
PATCH_SUBDIRS+=	client

.if !defined(NOPORTDOCS)
PORTDOCS=
.endif
BIN_FILES=	dhclient
LOCAL_CONF_FILES=	dhclient.conf
SAMP_FILES=	client/dhclient.conf

SAMP_SUFX=	.sample

CONF_DIR=	${PREFIX}/etc
SCHEMA_DIR=	${PREFIX}/share/${PKGBASE}
DOCSDIR=	${PREFIX}/share/doc/${PKGBASE}
DATADIR=	/var/db

PLIST_SUB+=	SCHEMA_DIR="${SCHEMA_DIR:S,^${PREFIX}/,,}"
PLIST_SUB+=	LDAP="@comment "
REINPLACE_SUB=	PREFIX=${PREFIX}
.if !defined(WITHOUT_DHCP_PARANOIA)
SUB_LIST+=	PARANOIA=YES
.else
SUB_LIST+=	PARANOIA=NO
.endif
.if !defined(WITHOUT_DHCP_JAIL)
SUB_LIST+=	JAIL=YES
.else
SUB_LIST+=	JAIL=NO
.endif
PKGMESSAGE_SUB=	PREFIX="${PREFIX}" MAN1PREFIX="${MAN1PREFIX}" \
		DOCSDIR="${DOCSDIR}" SCHEMA_DIR="${SCHEMA_DIR}"

# Post-extract
#

post-extract: extract-omshell extract-script

extract-omshell:
	@${MKDIR} ${WRKSRC}/omshell
	@${MV} ${WRKSRC}/dhcpctl/omshell.? ${WRKSRC}/omshell
	@${CP} ${FILESDIR}/omshell::Makefile.dist \
		${WRKSRC}/omshell/Makefile.dist

extract-script:
	@${CP} ${FILESDIR}/client::scripts::freebsd ${WRKSRC}/client/scripts/freebsd

# Post-patch
#

post-patch: patch-scripts patch-makefile-conf \
	    patch-makefiles-dist patch-man-pages \
	    patch-pkgmessage patch-site-conf

patch-scripts:
	@${REINPLACE_CMD} ${REINPLACE_SUB:S/$/!g/:S/^/ -e s!%%/:S/=/%%!/} \
		${WRKSRC}/client/dhclient.conf \
		${WRKSRC}/client/scripts/freebsd

patch-site-conf:
	@${ECHO_CMD} CFLAGS += -DENABLE_POLLING_MODE >> ${WRKSRC}/site.conf

patch-makefile-conf:
	@${REINPLACE_CMD} -e 's|^DEBUG[ 	]*=|# DEBUG ?=|g' \
		${WRKSRC}/Makefile.conf

patch-makefiles-dist:
.for subdir in ${PATCH_SUBDIRS}
	@${REINPLACE_CMD} -e 's|^CFLAGS[ 	]*=|CFLAGS +=|g' \
		${WRKSRC}/${subdir}/Makefile.dist
.endfor

# temporary hack - no patch file needed for this typo.
patch-man-pages:
	@${REINPLACE_CMD} -e '/^\.Fd$$/d' ${WRKSRC}/dhcpctl/dhcpctl.3

patch-pkgmessage:
	@${SED} ${PKGMESSAGE_SUB:S/$/!g/:S/^/ -e s!%%/:S/=/%%!/} \
		${MSG_FILE} > ${PKGMESSAGE}
	@${REINPLACE_CMD} -e '/^%%LDAP%%/d' ${PKGMESSAGE}


# Post-install
#

POST-INSTALL=	parallel-post-install install-rc-script configure-package \
		display-message
.ORDER: ${POST-INSTALL}
post-install: ${POST-INSTALL}

parallel-post-install: \
	strip-binary-files \
	install-doc-files install-sample-files \
	create-conf-files create-data-files

strip-binary-files:
.for f in ${BIN_FILES}
.if exists(${PREFIX}/bin/${f})
	@${STRIP_CMD} ${PREFIX}/bin/${f}
.endif
.if exists(${PREFIX}/sbin/${f})
	@${STRIP_CMD} ${PREFIX}/sbin/${f}
.endif
.endfor

install-doc-files:
.if !defined(NOPORTDOCS)
	@${MKDIR} ${DOCSDIR}
.for f in ${PORTDOCS}
	@${INSTALL_DATA} ${WRKSRC}/${f} ${DOCSDIR}
.endfor
.endif

install-sample-files:
.for f in ${SAMP_FILES}
	@${INSTALL_DATA} ${WRKSRC}/${f} ${CONF_DIR}/${f:T}${SAMP_SUFX}
.endfor

create-conf-files:
.for f in ${LOCAL_CONF_FILES}
.if !exists(${CONF_DIR}/${f})
	@${TOUCH} ${CONF_DIR}/${f}
.endif
.endfor

create-data-files:

install-rc-script:

configure-package:

display-message:
	@${ECHO_MSG}
	@${CAT} ${PKGMESSAGE}
	@${ECHO_MSG}

.include <bsd.port.post.mk>
