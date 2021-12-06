PORTNAME=	IO-EventMux
PORTVERSION=	2.02
CATEGORIES=	misc perl5
MASTER_SITES=	${MASTER_SITE_PERL_CPAN}
MASTER_SITE_SUBDIR=	IO/TLBDK
PKGNAMEPREFIX=	p5-

MAINTAINER=	erwin@FreeBSD.org
COMMENT=	Perl Multiplexer for sockets, pipes and non-blocking filehandles

RUN_DEPENDS=    ${SITE_PERL}/${PERL_ARCH}/IO/EventMux/Socket/MsgHdr.pm:${PORTSDIR}/misc/p5-IO-EventMux-Socket-MsgHdr
BUILD_DEPENDS=	${RUN_DEPENDS}

# old school
PERL_CONFIGURE=	5.8.0+
PERL_MODBUILD=	yes

# new school
USES=		perl5
USE_PERL5=	configure modbuild

NO_STAGE=	yes

MAN3=		IO::EventMux.3 IO::EventMux::Dump.3

.include <bsd.port.mk>
