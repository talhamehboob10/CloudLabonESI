%module hv
%{
//
// Copyright (c) 2004 University of Utah and the Flux Group.
// 
// {{{EMULAB-LICENSE
// 
// This file is part of the Emulab network testbed software.
// 
// This file is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
// 
// This file is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
// 
// You should have received a copy of the GNU Affero General Public License
// along with this file.  If not, see <http://www.gnu.org/licenses/>.
// 
// }}}
//

#include <string>
NAMESPACEHACK

#include "HypView.h"
%}

/* Magic from /usr/local/share/doc/swig/Doc/Manual/Python.html
 * "19.8.2 Expanding a Python object into multiple arguments".
 */
%typemap(in) (int argc, char *argv[]) {
  /* Check if is a list */
  if (PyList_Check($input)) {
    int i;
    $1 = PyList_Size($input);
    $2 = (char **) malloc(($1/*size*/+1)*sizeof(char *));
    for (i = 0; i < $1; i++) {
      PyObject *o = PyList_GetItem($input,i);
      if (PyString_Check(o))
	$2[i] = PyString_AsString(PyList_GetItem($input,i));
      else {
	PyErr_SetString(PyExc_TypeError,"list must contain strings");
	free($2);
	return NULL;
      }
    }
    $2[i] = 0;
  } else {
    PyErr_SetString(PyExc_TypeError,"not a list");
    return NULL;
  }
}
%typemap(freearg) (int argc, char **argv) {
  free((char *) $2);
}

// It's easier to return the pointer to the HypView object rather than access the global.
//extern HypView  *hvmain(int argc, char *argv[], int window, int width, int height);

#ifndef WIN32
extern HypView *hvMain(int argc, char *argv[], void *window, int width, int height);
#else
extern HypView *hvMain(int argc, char *argv[], int window,  int width, int height);
#endif
//extern int hvmain(int argc, char *argv[]);
//%include "cpointer.i"
//%pointer_class(HypView,hvp)
//extern HypView *hv;

extern void hvKill(HypView *hv);

// Separate out file reading from the main program.
extern int hvReadFile(char *fname, int width, int height);

// Get the node id string last selected by the selectCB function.
extern char const *getSelected();

// Get the node id string at the graph center.
extern char *getGraphCenter();

// std::string is used for INPUT args to HypView methods.
%include "std_string.i"
// How come %apply doesn't work for std::string?  Workaround with sed instead.
///namespace std {
//%apply const std::string & INPUT { const string & id };
///}

// This callback is used in picking.  Call it to simulate picking.
extern void selectCB(const std::string & INPUT, int shift, int control);

//================================================================

