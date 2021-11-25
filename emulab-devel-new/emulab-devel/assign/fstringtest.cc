/*
 * Copyright (c) 2005-2006 University of Utah and the Flux Group.
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
 *
 * Test program for the fstring library.
 */

static const char rcsid[] = "$Id: fstringtest.cc,v 1.4 2009-05-20 18:06:08 tarunp Exp $";

#include "fstring.h"
#include <iostream>
using namespace std;
#include <ext/hash_map>
using namespace __gnu_cxx;
#include <map>
using namespace std;

typedef map<fstring,int> stringmap;
typedef hash_map<fstring,int> stringhmap;

int main() {
	fstring string1("Hybrid Rainbow");
	cout << "string1 is " << string1 << ", hashes to " << string1.hash() << endl;
    cout << "unique strings: " << fstring::count_unique_strings() << endl;
	fstring string2("Blues Drive Monster");
	cout << "string2 is " << string2 << ", hashes to " << string2.hash() << endl;
    cout << "unique strings: " << fstring::count_unique_strings() << endl;
	fstring string3("Hybrid Rainbow");
	cout << "string3 is " << string3 << ", hashes to " << string3.hash() << endl;
    cout << "unique strings: " << fstring::count_unique_strings() << endl;

    cout << "Does string1 == string3? ";
    if (string1 == string3) {
        cout << "yes";
    } else {
        cout << "no";
    }
    cout << endl;

    cout << "Does string1 == string2? ";
    if (string1 == string2) {
        cout << "yes";
    } else {
        cout << "no";
    }
    cout << endl;

    cout << endl << "map test" << endl;
    stringmap map;
    cout << "map[string1] = 1" << endl;
    map[string1] = 1;
    cout << "map[string2] = 2" << endl;
    map[string2] = 2;
    cout << "Testing: map[string1] = " << map[string1] << endl;
    cout << "Testing: map[string2] = " << map[string2] << endl;
    cout << "Testing: map[string3] = " << map[string3] << endl;

    cout << endl << "hash_map test" << endl;
    stringhmap hmap;
    cout << "hmap[string1] = 1" << endl;
    hmap[string1] = 1;
    cout << "hmap[string2] = 2" << endl;
    hmap[string2] = 2;
    cout << "Testing: hmap[string1] = " << hmap[string1] << endl;
    cout << "Testing: hmap[string2] = " << hmap[string2] << endl;
    cout << "Testing: hmap[string3] = " << hmap[string3] << endl;
	
}
