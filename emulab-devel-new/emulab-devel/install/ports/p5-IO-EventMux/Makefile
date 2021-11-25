PORTNAME=	IO-EventMux
PORTVERSION=	2.02
CATEGORIES=	misc perl5
MASTER_SITES=	CPAN
PKGNAMEPREFIX=	p5-

MAINTAINER=	erwin@FreeBSD.org
COMMENT=	Perl Multiplexer for sockets, pipes and non-blocking filehandles

BUILD_DEPENDS=	p5-IO-EventMux-Socket-MsgHdr>=0.02:${PORTSDIR}/misc/p5-IO-EventMux-Socket-MsgHdr
RUN_DEPENDS=	${BUILD_DEPENDS}

NO_ARCH=	yes
USES=		perl5
USE_PERL5=	modbuild

MAN3=		IO::EventMux.3 IO::EventMux::Dump.3

.include <bsd.port.mk>
