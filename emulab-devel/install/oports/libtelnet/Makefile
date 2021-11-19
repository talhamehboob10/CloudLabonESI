# New ports collection makefile for: libtelnet
# Date created:         22 May, 2012
# Whom:                 testbed-ops@flux.utah.edu

PORTNAME=	libtelnet
PORTVERSION=	0.21
CATEGORIES=	misc
MASTER_SITES=	http://www.emulab.net/distributions/

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	Library for Telnet protocol

HAS_CONFIGURE=	yes
CONFIGURE_ARGS+=--mandir=${MANPREFIX}/man
USE_GMAKE=	yes

EXTRA_PATCHES=	${FILESDIR}/no-posix-source

#MAN1=	telnet-chatd.1 telnet-client.1 telnet-proxy.1
#MAN3=	libtelnet.h.3 telnet_environ_t.3 telnet_event_t.3 \
#	telnet_event_t_compress_t.3 telnet_event_t_data_t.3 \
#	telnet_event_t_environ_t.3 telnet_event_t_error_t.3 \
#	telnet_event_t_iac_t.3 telnet_event_t_mssp_t.3 \
#	telnet_event_t_negotiate_t.3 telnet_event_t_subnegotiate_t.3 \
#	telnet_event_t_ttype_t.3 telnet_event_t_zmp_t.3 telnet_telopt_t.3

post-patch:
	@${REINPLACE_CMD} -e '/^pkgconfigdir =/s|=.*| \
		= ${PREFIX}/libdata/pkgconfig|' ${WRKSRC}/Makefile.in

# get rid of the test apps
post-install:
	${RM} -f ${PREFIX}/bin/telnet-chatd
	${RM} -f ${PREFIX}/bin/telnet-client
	${RM} -f ${PREFIX}/bin/telnet-proxy

NO_STAGE=	yes
.include <bsd.port.mk>
