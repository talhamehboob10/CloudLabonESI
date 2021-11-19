// graph2single-source.cc

/*
 * Copyright (c) 2004 University of Utah and the Flux Group.
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
#include <vector>

using namespace std;

int main()
{
    int bits = 0;
    int weight = 0;
    vector<int> hosts;
    string lineString;
    getline(cin, lineString);
    while (cin)
    {
        hosts.clear();
        istringstream line(lineString);
        int tempHost = 0;

        line >> bits >> weight;
        line >> tempHost;
        while(line)
        {
            hosts.push_back(tempHost);
            line >> tempHost;
        }

        for (size_t i = 0; i < hosts.size(); ++i)
        {
            for (size_t j = i + 1; j < hosts.size(); ++j)
            {
                cout << "I " << hosts[i] << " " << hosts[j] << " "
                     << static_cast<float>(weight) << endl;
            }
        }

        getline(cin, lineString);
    }

    cout << "C" << endl;
    return 0;
}
