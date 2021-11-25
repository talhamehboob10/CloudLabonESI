// brite2graph.cc

/*
 * Copyright (c) 2003 University of Utah and the Flux Group.
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

#include <iostream>
#include <string>
#include <sstream>

using namespace std;

int main()
{
    string bufferString;
    getline(cin, bufferString);
    while (cin && bufferString.substr(0, 5) != "Edges")
    {
        getline(cin, bufferString);
    }

    getline(cin, bufferString);
    while (cin)
    {
        size_t temp = 0;
        size_t source = 0;
        size_t dest = 0;
        istringstream buffer(bufferString);
        buffer >> temp >> source >> dest;
        cout << "2 1 " << source << ' ' << dest << endl;
        getline(cin, bufferString);
    }

    return 0;
}
