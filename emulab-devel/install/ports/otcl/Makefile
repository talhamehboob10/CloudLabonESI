# Created by: obonilla
# $FreeBSD: head/lang/otcl/Makefile 362717 2014-07-23 17:30:45Z bapt $

PORTNAME=	otcl
PORTVERSION=	1.14
DISTVERSIONPREFIX=	src-
CATEGORIES=	misc lang tcl tk
MASTER_SITES=	SF/${PORTNAME}-tclcl/OTcl/${PORTVERSION}

MAINTAINER=	ports@FreeBSD.org
COMMENT=	MIT Object Tcl

LICENSE=	MIT

WRKSRC=		${WRKDIR}/${PORTNAME}-${PORTVERSION}

USES+=		tk
USE_XORG=	xext

USE_AUTOTOOLS=	autoconf
GNU_CONFIGURE=	yes
USES+=		autoreconf
USE_LDCONFIG=	yes

MAKE_JOBS_UNSAFE=yes

.include <bsd.port.pre.mk>

CFLAGS+=	-DHAVE_UNISTD_H
CONFIGURE_ARGS+=--with-tcl=${LOCALBASE} \
		--with-tk=${LOCALBASE} \
		--with-tcl-ver=${TCL_VER}

.if ${TCL_SHLIB_VER} > 85
CFLAGS+=	-DUSE_INTERP_ERRORLINE -DUSE_INTERP_RESULT
.endif

post-extract:
	@echo WRKSRC is ${WRKSRC}

post-patch:
	@${REINPLACE_CMD} -e 's|/usr/X11R6|${LOCALBASE}|g' \
		-e's|X11/Intrinsic.h|X11/Xlib.h|g' \
		${WRKSRC}/configure ${WRKSRC}/conf/configure.in.x11
	@${REINPLACE_CMD} -e 's|../lib/tcl$$TCL_HI_VERS|${TCL_LIBDIR}|g' \
		-e 's|../include|${TCL_INCLUDEDIR}/generic|g' \
		${WRKSRC}/conf/configure.in.tcl
	@${REINPLACE_CMD} -e 's|../lib/tk$$TK_HI_VERS|${TK_LIBDIR}|g' \
		-e 's|../include|${TK_INCLUDEDIR}/generic|g' \
		${WRKSRC}/conf/configure.in.tk

.include <bsd.port.post.mk>
