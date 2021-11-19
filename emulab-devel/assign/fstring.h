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

#ifndef FSTRING_H_
#define FSTRING_H_

/*
 * fstring - a "fast string" implementation for strings which are:
 * 	- constant
 * 	- seldom created
 * 	- often compared
 * 	- often hashed
 *      - never _lexographically_ compared
 * The intended bounds for this class are:
 *      - O(n) total storage in the number of _unique_ fstrings in use
 *      - O(1) time for comparison of any two fstrings
 *          (ie. length of strings does not matter)
 *      - O(1) hashing time for any string
 */

#include "port.h"

#include <iostream>
#include <map>
#include <cstring>
using namespace std;

#ifdef NEW_GCC
#ifdef NEWER_GCC
  #include <backward/hash_fun.h>
#else
  #include <ext/hash_fun.h>
#endif
using namespace __gnu_cxx;
#elif ! defined __clang__
#include <stl_hash_fun.h>
#endif

#include <string>
using namespace std;

class fstring {
    /*
     * Note: There are several functions here I'd rather put into the .cc file,
     * but I want them to be inlined.
     */
    public:
        // TODO - I want to get rid of the default constuctor, but it's still
        // needed in a few places in assign
        inline fstring() : str(NULL) {;};
		
        /*
         * This is the constructor that should normally be used
         * NOTE: this constructor might be explicit later to avoid unintended
         * conversions from char*s to fstrings.
         */
        inline fstring(const char *_str) {
            if (_str[0] == '\0') { str = emptystr; }
            else { str = unique_string(_str); }
        };

        inline fstring(const string _str) {
            if (_str[0] == '\0') { str = emptystr; }
            else { str = unique_string(_str.c_str()); }
        };
		
        /*
         * Nothing to do here for now, but we might want to consider reclaiming
         * unused strings later
         */
        inline ~fstring() {};
		
        /*
         * Operators
         */
        inline bool operator==(const fstring &other) const {
            return str == other.str;
        }
        inline bool operator!=(const fstring &other) const {
            return (other.str != this->str);
        }
        inline bool operator<(const fstring &other) const {
            return (str < other.str);
        }
        inline bool operator>(const fstring &other) const {
            return (str > other.str);
        }
        inline const char operator[](const int i) const {
            // TODO: Bounds checking?
            return str[i];
        }
        // Note: This operator hopefully will not be used very often, but some
        // of the parsing code wants it
        inline fstring operator+(const fstring &other) const {
            char *newbuffer =
                (char*)malloc(1 + strlen(other.str) + strlen(this->str));
            strcpy(newbuffer,this->str);
            strcat(newbuffer,other.str);
            fstring newstr(newbuffer);
            free(newbuffer);
            return newstr;
        }
        // Note: I also don't want to have this function here, but again,
        // the parsing code needs it for now (I plan to fix this later -
        // ricci)
        inline void pop_front() {
            const char *tmpstr = this->str + 1;
            if (tmpstr[0] == '\0') {
                this->str = emptystr;
            } else {
                this->str = unique_string(tmpstr);
            }
        }

         /*
          * Operator for comparison with char*s
          */
        inline bool operator==(const char *other) const {
            return (strcmp(other, this->str) == 0);
        }

        // Fast test for empty strings
        inline bool empty() const {
            return ((str == NULL) || (str[0] == '\0'));
        }
		
        /*
         * Output/debugging functions
         */
        friend ostream &operator<<(ostream &o, const fstring &s) {
            if (s.str != NULL) {
                return(o << s.str);
            } else {
                return(o << "(null)");
            }
        }
		
		
        inline const char *c_str() const {
            return str;
        } 

        static unsigned int count_unique_strings() {
            return all_strings.size();
        }
		
		
        /*
         * Hash function, suitable for putting fstrings into a hash_map or the
         * like
         */
        inline size_t hash() const {
            return (size_t)str;
        }

    private:
        // This is the only a pointer to the One True Copy of the the string
	const char *str;

        /*
         * Used so that we can put char*s in maps
         */
        struct ltstr {
          bool operator()(const char* s1, const char* s2) const {
            return (strcmp(s1, s2) < 0);
          }
        };
        
        /*
         * We keep only one copy of each duplciated string, by putting it in 
         * the hash below. This way, we can do very fast compares and hashes
         * by comparing and hashing pointers.
         * We do kind of a funny thing by using the same pointer for the key
         * and the value - in the future, we could put something more useful
         * in the value, like a refcount and maybe a length
         */
        typedef map<const char*, const char*, ltstr> stringmap;
        static stringmap all_strings;

        /*
         * Return a unique pointer to the given string from the stringmap,
         * creating it if necessary
         */
        static const char *unique_string(const char *str);

        /*
         * We'll use a special value for the empty string so that we don't have
         * to find it in the map - this is a very common operation.
         */
        static const char *emptystr;
};

// A hash function for fstrings
#if defined NEW_GCC
namespace __gnu_cxx {
#endif
#if defined __clang__
template<> struct std::hash<fstring> {
  size_t operator()(const fstring& __str) const
  {
  	return (size_t)__str.hash();
  }
};
#else
template<> struct hash<fstring> {
  size_t operator()(const fstring& __str) const
  {
  	return (size_t)__str.hash();
  }
};
#endif
#if defined NEW_GCC
}
#endif

#endif /*FSTRING_H_*/
