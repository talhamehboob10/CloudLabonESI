// inet2graph.cc

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
    string headerString;
    getline(cin, headerString);
    if (cin)
    {
        istringstream header(headerString);
        size_t nodeCount = 0;
        string bufferString;
        header >> nodeCount;
        for (size_t i = 0; i < nodeCount; ++i)
        {
            getline(cin, bufferString);
        }
        getline(cin, bufferString);
        while (cin)
        {
            istringstream buffer(bufferString);
            size_t first = 0;
            size_t second = 0;
            size_t weight = 0;
            buffer >> first;
            buffer >> second;
            buffer >> weight;
            cout << "8 " << weight << ' ' << first << ' ' << second << endl;
            getline(cin, bufferString);
        }
    }
    return 0;
}
