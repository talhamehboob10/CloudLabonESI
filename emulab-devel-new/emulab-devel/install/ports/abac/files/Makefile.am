#
# libabac
# (0.1.7)
bin_PROGRAMS = libabac/abac_prover libabac/abac_prover_plus \
	       creddy/creddy
EXTRA_DIST = doc java cred_printer tests

lib_LTLIBRARIES = libabac/libabac.la
libabac_libabac_la_SOURCES = \
    libabac/abac.c \
    libabac/abac.h \
    libabac/abac_list.c \
    libabac/abac_list.h \
    libabac/abac_graph.c \
    libabac/abac_graph.h \
    libabac/abac_keyid_map.c \
    libabac/abac_role.c \
    libabac/abac_set.c \
    libabac/abac_set.h \
    libabac/abac_xml.c \
    libabac/abac_xml.h \
    libabac/abac_openssl.c \
    libabac/abac_openssl.h \
    libabac/abac_id.c \
    libabac/abac_attribute.c \
    libabac/abac_util.c \
    libabac/abac_util.h \
    libabac/abac_verifier.c \
    libabac/abac_verifier.h \
    libabac/compat/readpassphrase.c \
    libabac/compat/readpassphrase.h \
    libabac/libabac_common.h \
    libabac/uthash.h \
    libabac/utlist.h
libabac_libabac_la_LDFLAGS = -version-info 2:0:0
libabac_libabac_la_LIBADD = $(XML2_LDFLAGS) $(XMLSEC1_LDFLAGS) $(OPENSSL_LIBS)

libabac_abac_prover_SOURCES = libabac/prover.c libabac/options.c libabac/options.h \
                              libabac/abac.h
libabac_abac_prover_LDADD = $(top_builddir)/libabac/libabac.la

libabac_abac_prover_plus_SOURCES = libabac/prover_plus.cc libabac/options.c \
                                   libabac/options.h libabac/abac.hh
libabac_abac_prover_plus_LDADD = $(top_builddir)/libabac/libabac.la

#
# creddy
#
creddy_creddy_SOURCES = \
    creddy/creddy_common.h \
    creddy/attribute.c \
    creddy/attribute_rule.c \
    creddy/creddy.c \
    creddy/display.c \
    creddy/generate.c \
    creddy/keyid.c \
    creddy/roles.c \
    creddy/verify.c
creddy_creddy_LDADD = $(top_builddir)/libabac/libabac.la
man1_MANS = doc/creddy.1

#
# Perl
#
perldir = @SITE_PERL@
bin_SCRIPTS = swig/perl/abac_prover.pl 
perl_SCRIPTS = swig/perl/abac_wrap.cxx swig/perl/ABAC.pm 
perl_LTLIBRARIES = swig/perl/ABAC.la 
# Swig/Perl/ABAC
swig_perl_ABAC_la_SOURCES = swig/perl/abac_wrap.cxx swig/perl/SSL_keyid.c \
                            swig/perl/SSL_keyid.h  swig/perl/ABAC.pm      \
                            swig/perl/chunk.i swig/perl/language.i \
                            swig/perl/abac_prover.pl
swig_perl_ABAC_la_CPPFLAGS = `perl -MExtUtils::Embed -e ccopts`
swig_perl_ABAC_la_LDFLAGS = -module
swig_perl_ABAC_la_LIBADD = $(top_builddir)/libabac/libabac.la -lssl

# ABAC.pm is created as a side effect
swig/perl/ABAC.pm swig/perl/abac_wrap.cxx: swig/perl/chunk.i swig/perl/language.i
	if test ! -e swig/perl/abac.h ; then \
		$(LN_S) $(abs_srcdir)/libabac/abac.h swig/perl/abac.h ; \
	fi
	if test ! -e swig/perl/abac.hh ; then \
		$(LN_S) $(abs_srcdir)/libabac/abac.hh swig/perl/abac.hh ; \
	fi
	if test ! -e swig/perl/abac.i ; then \
		$(LN_S) $(abs_srcdir)/swig/abac.i swig/perl/abac.i ; \
	fi
	$(SWIG) -perl -o swig/perl/abac_wrap.cxx swig/perl/abac.i

# misc
INCLUDES = -I$(top_builddir)/libabac \
           $(XMLSEC1_INCLUDES) $(XML2_INCLUDES) $(OPENSSL_INCLUDES)

AM_CFLAGS = -DABAC_VERSION=\""$(VERSION)\"" -Wall -Werror

ACLOCAL_AMFLAGS=-I m4

CLEANFILES = $(perl_SCRIPTS)

library_includedir=$(includedir)
library_include_HEADERS = libabac/abac.h libabac/abac.hh 

.PHONY:	clean-local-java install-exec-local clean-local-doc clean-local-swig clean-local-tests testing api

clean-local:	clean-local-java clean-local-doc clean-local-swig clean-local-tests

clean-local-java:
	if which ant 2> /dev/null ; then \
		cd java && ant clean ; \
	fi

clean-local-doc:
	rm -rf doc/extract_doc

clean-local-swig:
	rm -rf swig/perl/abac_wrap.cxx

clean-local-tests:
	cd tests && ( if [ -f Makefile ]; then make clean; fi)

dist-hook:
	if which ant ; then \
		cd $(distdir)/java && ant clean ; \
	fi
	cd tests && ( if [ -f Makefile ]; then make clean; fi)
	cd cred_printer && make clean

api: doc/extract_doc.c
	$(CC) -o doc/extract_doc doc/extract_doc.c
	cp libabac/abac.hh doc/abac.hh	
	cd doc && pwd && ./extract_doc

testing: 
	cd tests && make clean && make -s tests

install-data-hook:
	@echo ''
	@echo '+--------------------------------------------------------------+'
	@echo '| A friendly reminder:                                         |'
	@echo '| If you have not already run "make testing", then we strongly |'
	@echo '|   recommend you do so to expose any possible setup problem   |'
	@echo '| For testing Java api, please run "ant regression-test"       |'
	@echo '|   in java directory                                          |'
	@echo '+--------------------------------------------------------------+'
	@echo ''


