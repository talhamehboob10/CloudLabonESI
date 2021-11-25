# ports collection makefile for: emulab-extras
# Date created:         15 June 2015
# Whom:                 testbed-ops@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

PORTNAME=	emulab-extras
PORTVERSION=	${EMULAB_PORTVERSION}
CATEGORIES=	misc
MASTER_SITES=	#none
DISTFILES=	#none
EXTRACT_ONLY=	#none

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Extra convenience packages for Emulab"

NO_BUILD=	yes

#
# This prevents any ports from trying to configure interactively.
#
BATCH=		yes
.MAKEFLAGS+=	-DBATCH

#
# XXX hackary to get around bugs in Makefiles:
#
# Both pango (required by graphviz) and gtk-update-icon-cache (required by
# emacs) perform a Makefile (pre-configure target) existence check using
# ".if exists" for the cairo port. However, since that check is done at
# Makefile parse time, the things they are checking for might not yet be
# installed. Instead those items get installed as a result of the dependencies
# in the Makefile. The Makefiles should really be changed to make run-time
# check (i.e., a shell "test" command) for the existence of packages that
# they might install.
#
RUN_DEPENDS=	\
	${LOCALBASE}/libdata/pkgconfig/cairo-gobject.pc:${PORTSDIR}/graphics/cairo

# XXX do vim-lite to avoid dragging in gtk
RUN_DEPENDS+=	\
	bash:${PORTSDIR}/shells/bash \
	${LOCALBASE}/sbin/e2fsck:${PORTSDIR}/sysutils/e2fsprogs \
	emacs:${PORTSDIR}/editors/emacs \
	git:${PORTSDIR}/devel/git \
	jove:${PORTSDIR}/editors/jove \
	lsof:${PORTSDIR}/sysutils/lsof \
	rsync:${PORTSDIR}/net/rsync \
	sudo:${PORTSDIR}/security/sudo \
	xauth:${PORTSDIR}/x11/xauth \
	xterm:${PORTSDIR}/x11/xterm \
	zsh:${PORTSDIR}/shells/zsh \
	vim:${PORTSDIR}/editors/vim-console
.if (${EMULAB_PORTVERSION} == "8.2")
RUN_DEPENDS+=	\
	gdb:${PORTSDIR}/devel/gdb
.endif

RUN_DEPENDS+=	\
	${PYTHON_PKGNAMEPREFIX}subversion>0:${PORTSDIR}/devel/py-subversion

USES=		python:$(PY_VER)

do-install:	# empty

.include <bsd.port.mk>
