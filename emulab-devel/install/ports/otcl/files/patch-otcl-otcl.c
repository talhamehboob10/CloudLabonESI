--- otcl.c.orig	2014-08-22 17:10:18.000000000 -0700
+++ otcl.c	2014-08-22 18:36:45.000000000 -0700
@@ -462,7 +462,12 @@
 	     */
 	    CONST84 char *old_args2 = cl ? (char *) Tcl_GetCommandName(in, cl->object.id) : argv[0];
 	    sprintf(msg, "\n    (%.40s %.40s line %d)",
-		    old_args2, argv[1], in->errorLine);
+		    old_args2, argv[1], 
+#if TCL_MINOR_VERSION <= 4                                       
+                                      in->errorLine);
+#else
+                                      Tcl_GetErrorLine(in));
+#endif
 	    compat_Tcl_AddObjErrorInfo(in, msg, -1);
     }
     if (argc+2 > OTCLSMALLARGS) { ckfree((char*)args); args = 0; }
@@ -499,7 +504,12 @@
     if (result == TCL_ERROR) {
 	    char msg[100];
 	    sprintf(msg, "\n    (%.30s unknown line %d)",
-		    cl ? args[2] : argv[0], in->errorLine);
+		    cl ? args[2] : argv[0], 
+#if TCL_MINOR_VERSION <= 4
+                                          in->errorLine);
+#else
+                                          Tcl_GetErrorLine(in));
+#endif
 	    compat_Tcl_AddObjErrorInfo(in, msg, -1);
     }
     if (argc+3 > OTCLSMALLARGS) { ckfree((char*)args); args = 0; }
@@ -781,7 +791,7 @@
   if (hPtr) {
     Tcl_CmdInfo* co = (Tcl_CmdInfo*)Tcl_GetHashValue(hPtr);
     if (co->proc == ProcInterpId)
-      return Tcl_CmdInfoGetProc(co);
+      return (Proc *) Tcl_CmdInfoGetProc(co);
   }
   return 0;
 }
@@ -1601,7 +1611,12 @@
   (void)RemoveInstance(obj, obj->cl);
   AddInstance(obj, cl);
 
-  result = Tcl_VarEval(in, argv[4], " init ", in->result, 0);
+  result = Tcl_VarEval(in, argv[4], " init ", 
+#if TCL_MINOR_VERSION <= 4
+                                         in->result, 0);
+#else
+                                         Tcl_GetStringResult(in), 0);
+#endif
   if (result != TCL_OK) return result;
   Tcl_SetResult(in, (char *)argv[4], TCL_VOLATILE);
   return TCL_OK;
