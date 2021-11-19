# Created by: Gary Wong <gtw@flux.utah.edu>
#
# Mike uglified. This won't fully work with python3. The swig stub code
# cannot handle the FILE* interfaces (which are not a part of python3),
# and it was not worth my time to fix them. Since we don't use the python
# stubs in our code (just perl), I ripped python stuff out of Makefile.in
# and the configure file. I tried changing Makefile.am but then ran into
# all kinds of issues due to the different versions of autotools in use
# between older FreeBSD and newer.
#
# We also needed a patch for newer versions of OpenSSL.
#

PORTNAME=	abac
PORTVERSION=	0.1.9
CATEGORIES=	misc
MASTER_SITES=	http://mirror.deterlab.net/share/images/VARIOUS/abac/ \
		http://www.emulab.net/downloads/

MAINTAINER=	testbed-ops@flux.utah.edu
COMMENT=	"Attribute-Based Access Control library, as adopted by GENI"

.include <bsd.port.options.mk>

#
# Set to "yes" for 11.3 and before with swig3 and python2
#   Builds python interfaces as well as perl.
# Set to "no" for 12.2 or later with no swig3 and no python2
#   Builds only perl interfaces. Requires hacked-up Makefile.am
#   and configure.ac.
#
.if (${OSVERSION} >= 1202000)
PRE_2021_PORTS=	no
.else
PRE_2021_PORTS=	yes
.endif

GNU_CONFIGURE=	yes
.if (${PRE_2021_PORTS} == "yes")
USE_AUTOTOOLS=	autoconf
USES=		gmake libtool perl5 python
BINARY_ALIAS=	swig=swig3.0
.else
PLIST=		${PKGDIR}/pkg-plist-nopython
EXTRA_PATCHES=	${FILESDIR}/emulab-patch-abac-openssl
USES=		autoreconf gmake libtool perl5
.endif
CPPFLAGS+=	-I${LOCALBASE}/include
LDFLAGS+=	-L${LOCALBASE}/lib

BUILD_DEPENDS=	xmlsec1:${PORTSDIR}/security/xmlsec1

pre-configure:
.if (${PRE_2021_PORTS} == "no")
	@${CP} "${FILESDIR}/Makefile.am" "${WRKSRC}/Makefile.am"
	@${CP} "${FILESDIR}/configure.ac" "${WRKSRC}/configure.ac"
.endif

post-configure:
.if (${PRE_2021_PORTS} == "no")
	# no freakin clue why this gets added, but causes includes
	# of the standard <err.h> file to get the unrelated openssl version
	@sed -i .orig -e 's;-I/usr/include/openssl;;' "${WRKSRC}/Makefile"
.endif

.include <bsd.port.mk>
