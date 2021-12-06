PORTNAME=	IO-EventMux-Socket-MsgHdr
PORTVERSION=	0.02
CATEGORIES=	misc perl5
MASTER_SITES=	${MASTER_SITE_PERL_CPAN}
MASTER_SITE_SUBDIR=	IO/TLBDK
PKGNAMEPREFIX=	p5-

MAINTAINER=	sklower@berkeley.edu
COMMENT=	sendmsg, recvmsg and ancillary data in Perl5

# old school
#PERL_CONFIGURE=	5.8.0+
#PERL_MODBUILD=	yes

# new school
USES=		perl5
USE_PERL5=	configure modbuild

NO_STAGE=	yes

MAN3=		IO::EventMux::Socket::MsgHdr.3

.include <bsd.port.mk>
