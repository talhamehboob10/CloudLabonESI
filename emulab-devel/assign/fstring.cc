/*
 * Copyright (c) 2005-2010 University of Utah and the Flux Group.
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

static const char rcsid[] = "$Id: fstring.cc,v 1.4 2009-05-20 18:06:08 tarunp Exp $";

#include "fstring.h"

fstring::stringmap fstring::all_strings;
const char *fstring::emptystr = "";

const char *fstring::unique_string(const char *str) {
    // First, check to see if this string is already in the map
    stringmap::const_iterator it = all_strings.find(str);
    if (it == all_strings.end()) {
        // Not in there, insert it and return the new string
        char *stored_str = (char*)malloc(strlen(str) + 1);
        strcpy(stored_str,str);
        all_strings[stored_str] = stored_str;
        return stored_str;
    } else {
        return it->second;
    }
}

/*
 * Note: Many functions are in the header file, becuase I want them
 * inlined
 */
