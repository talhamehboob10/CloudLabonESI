# New ports collection makefile for: emulab-php5
# Date created:         09 February 2006
# Whom:                 stoller@flux.utah.edu

.include "../emulab-boss/Makefile.emulab"

#
# These are for the php5-extensions port.
# We need a specific set of extensions that is slightly different than
# the default.
#

#
# This prevents the option screen.
#
BATCH=yes

WITH_XMLRPC=yes
WITH_CURL=yes
WITH_OPENSSL=yes
WITH_BZ2=yes
WITH_GD=yes
WITH_MCRYPT=yes
WITH_MHASH=yes
WITH_MYSQL=yes
WITH_XML=yes
WITH_SOCKETS=yes

WITHOUT_SQLITE=true
WITHOUT_PDO_SQLITE=true

.MAKEFLAGS+=	-DBATCH APACHE_PORT=www/apache22 WITH_APACHE=yes

PKGORIGIN=		misc/emulab-php5
.include "../../lang/php5-extensions/Makefile"

vars:
	@echo "PORTVERSION=$(PORTVERSION)"
	@echo "EMULAB_PORTVERSION=$(EMULAB_PORTVERSION)"
	@echo ".MAKEFLAGS=$(.MAKEFLAGS)"
	@echo "BUILD_DEPENDS=$(BUILD_DEPENDS)"
	@echo "LIB_DEPENDS=$(LIB_DEPENDS)"
	@echo "RUN_DEPENDS=$(RUN_DEPENDS)"
	@echo "PERL_VER/ARCH=${PERL_VER}/${PERL_ARCH}"
	@echo "APACHE_PORT=${APACHE_PORT}"
