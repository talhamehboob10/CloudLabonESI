--- conf/configure.in.tcl.orig	2015-01-20 14:47:53.000000000 -0800
+++ conf/configure.in.tcl	2015-01-20 14:48:31.000000000 -0800
@@ -10,7 +10,7 @@
 
 TCL_HI_VERS=`echo $TCL_VERS | sed 's/^\([[0-9]]*\)\.\([[0-9]]*\)\.\([[0-9]]*\)/\1.\2/'`
 TCL_MAJOR_VERS=`echo $TCL_VERS | sed 's/^\([[0-9]]*\)\.\([[0-9]]*\)\.\([[0-9]]*\)/\1/'`
-TCL_ALT_VERS=8.5
+TCL_ALT_VERS=8.6
 
 dnl work with one version in the past
 TCL_OLD_VERS=8.4
