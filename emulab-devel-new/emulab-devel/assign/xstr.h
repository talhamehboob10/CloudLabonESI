/*
 * Copyright (c) 2005-2008 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 */

#ifndef __XSTR_H
#define __XSTR_H

#include <cstdio>
#include <string>
using namespace std;
#include <xercesc/util/XMLString.hpp>
XERCES_CPP_NAMESPACE_USE

#include "fstring.h"

/*
 * This class provides for conversion between Xerces' internal XMLCh* type
 * (which is 16 bits wide to hold international characters) and simple
 * char*s. You can construct an XStr with either type, and then call C() or
 * x() to get back the desired type of string. XStr works out on its own what
 * conversion needs to happen, and frees it up in its destructor (normally,
 * when it goes out of scope.)
 *
 * DO NOT MAKE POINTERS TO THIS CLASS - that would defeat the whole purpose
 * of it's string memory management.
 */
class XStr {
public:
    XStr(const char *_str) : cstr(_str), transcoded(NULL), xmlstr(NULL)
			     /*, fstr(NULL),
                             fstr_mine(false)  */ { ; };
    XStr(const XMLCh *_str) : cstr(NULL), transcoded(NULL), xmlstr(NULL)
			      /*, fstr(NULL), fstr_mine(false) */ {
	xmlstr = XMLString::replicate(_str);
    };
    XStr(const fstring &_str) : /* fstr_mine(true), */
      transcoded(NULL), xmlstr(NULL) {
	//fstr = new fstring(_str);
	cstr = _str.c_str();
    };
    
    ~XStr() {
	if (transcoded != NULL) {
	    XMLString::release(&transcoded);
	}
	if (xmlstr != NULL) {
	    XMLString::release(&xmlstr);
	}
	/*if (fstr_mine && fstr != NULL) {
	    delete fstr;
	}*/
    };
    
    /*
     * Convert to a Xerces string (XMLCh *)
     */
    const XMLCh *x() {
	if (this->xmlstr == NULL) {
	    this->xmlstr = XMLString::transcode(this->cstr);
	}
	return this->xmlstr;
    };
    
    /*
     * convert to a C-style string (null-terminated char*)
     */
    const char *c() {
	if (this->cstr == NULL) {
	    this->transcoded = XMLString::transcode(this->xmlstr);
	    this->cstr = this->transcoded;
	}
	return this->cstr;
    };
    
    /*
     * convert to the fstring type used internally in assign
     */
    fstring f() {
	/*if (this->fstr == NULL) {
	    this->fstr = new fstring(this->c());
	    this->fstr_mine = true;
	}*/
	return fstring(this->c());
    };
    
    /*
     * Convert to an integer - throws an exception if the string isn't
     * one
     */
    int i() {
	int converted;
	if (sscanf(this->c(),"%d",&converted) == 1) {
	    return converted;
	} else {
	    throw("Tried to convert an non-integer to an integer");
	}
    }
    
    /*
     * Convert to a double - throws and exception if the string isn't one
     */
    double d() {
	double converted;
	if (sscanf(this->c(),"%lf",&converted) == 1) {
	    return converted;
	} else {
	    throw("Tried to convert an non-double to a double");
	}
    }
    
    bool operator==(const char * const other) {
	return (strcmp(this->c(),other) == 0);
    };
    bool operator!=(const char * const other) {
	return (strcmp(this->c(),other) != 0);
    };
    
    /*
     * Crazy, I know, but this is how you tell C++ it can implicilty convert
     * an XString into other data types. Thanks to Jon Duerig and the ghost 
     * of Bjarne Stroustrup (really, his C++ book) for helping me figure 
     * this out.
     */
    operator const char*() { return this->c(); };
    // Note, this operator commented out because some functions that can 
    // take either a char* or an XMLch* get confused if we have conversions
    // to both
    //operator const XMLCh*() { return this->x(); };
    
private:
    const char *cstr;
    char * transcoded;
    XMLCh *xmlstr;

    /*
     * Make the copy and assignment constructors private - I haven't decided
     * on their semantics yet, and want to make sure they are not called
     * automatically
     */
    const XStr &operator=(const XStr& other) { return(other); };
    XStr(const XStr& other) { ; };
    
    /*
    fstring *fstr;
    bool fstr_mine;
     */
};

#endif
