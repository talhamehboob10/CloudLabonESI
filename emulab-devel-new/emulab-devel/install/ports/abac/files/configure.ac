AC_INIT([ABAC], [0.1.9], [faber@ISI.EDU])
AC_CONFIG_SRCDIR([libabac/abac_role.c])
AM_INIT_AUTOMAKE([foreign subdir-objects])
LT_INIT

AC_CONFIG_MACRO_DIR([m4])

# Checks for programs.
AC_PROG_CXX
AC_PROG_CC
AC_PROG_LIBTOOL

# Explicitly hunt up perl
AC_CHECK_PROGS(PERL, perl)

# for openssl
AX_CHECK_OPENSSL([], [AC_MSG_ERROR([openssl is required to build pacakge])] )

# for xmlsec1
AX_CHECK_XMLSEC1([], [AC_MSG_ERROR([xmlsec1 is required to build pacakge])] )
# for xml2
AX_CHECK_XML2([], [AC_MSG_ERROR([xml2 is required to build pacakge])] )

# for swig
AX_PKG_SWIG(1.3.17, [], [AC_MSG_ERROR([SWIG is required to build package])] )
AX_SWIG_ENABLE_CXX

AC_ARG_ENABLE(debug,
    [AC_HELP_STRING([--enable-debug], [build with debug symbols])],
    [CFLAGS+="-g "],[])

# Checks for libraries.
AC_ARG_WITH(
    [site-perl],
    [AS_HELP_STRING([--with-site-perl=DIR], 
		   [directory in which to install perl modules])],
    [SITE_PERL="$withval"], [SITE_PERL=""])
    

# Ask perl for a likely site_perl directory.  If the user has already specified
# it using --with-site-perl, use that value.  NB, this does not respect prefix,
# so users wishing to do a local install must use --with-site-perl
AC_MSG_CHECKING(for site_perl directory)
if test -z "$SITE_PERL"; then
	SITE_PERL=`$PERL -e 'print((grep(/site_perl/ && !m#/mach#, @INC))[0], "\n");'`
fi
AC_MSG_RESULT($SITE_PERL)
AC_SUBST(SITE_PERL)

AC_LANG(C)
# Checks for header files.
AC_CHECK_HEADERS([inttypes.h stddef.h stdlib.h string.h readpassphrase.h paths.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_HEADER_STDBOOL
AC_TYPE_SIZE_T
AC_TYPE_UINT16_T
AC_TYPE_UINT32_T
AC_TYPE_UINT8_T
AC_CHECK_TYPES([ptrdiff_t])
AC_MSG_CHECKING([checking for header-guard])
HOLD_CFLAGS=$CFLAGS
CFLAGS="$CFLAGS -Werror -Wno-error=header-guard"
AC_COMPILE_IFELSE([[]],AC_MSG_RESULT([yes]),CFLAGS=$HOLD_CFLAGS;AC_MSG_RESULT([no]))

AC_CHECK_DECL([_PATH_TTY],[],AC_DEFINE_UNQUOTED([_PATH_TTY],"/dev/tty",[Define to tty device node path]),[
#ifdef HAVE_PATHS_H
#  include <paths.h>
#endif
])

# Checks for library functions.
AC_FUNC_MALLOC
AC_CHECK_FUNCS([atexit memset strchr strdup readpassphrase])

AC_CONFIG_FILES([Makefile tests/Makefile tests/creddy_tests/Makefile tests/creddy_prover_tests/Makefile tests/attr_tests/Makefile tests/scaling_tests/Makefile tests/scaling_tests/daisychain/Makefile tests/scaling_tests/haystack/Makefile tests/scaling_tests/haystack/ralphs_prover/Makefile tests/example_scripts/Makefile tests/example_scripts/wiki/Makefile tests/example_scripts/c/Makefile tests/example_scripts/perl/Makefile])
AC_OUTPUT
