// difference.cc

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
#include <fstream>
#include <string>

using namespace std;

int main(int argc, char * argv[])
{
    if (argc == 3)
    {
        ifstream ideal(argv[1], ios::in);
        ifstream candidate(argv[2], ios::in);
        ofstream relative((argv[2] + string(".relative")).c_str(),
                         ios::out | ios::trunc);
        ofstream absolute((argv[2] + string(".absolute")).c_str(),
                         ios::out | ios::trunc);
        if (ideal && candidate && relative && absolute)
        {
            int left = 0;
            int right = 0;
            size_t total = 1;
            ideal >> left;
            candidate >> right;
            while (ideal && candidate)
            {
                if (right - left < 0)
                {
                    cerr << total << " ideal: " << left << " candidate: " << right << endl;
                }
                absolute << (right - left) << endl;
                double num = right - left;
                double denom = right;
                if (right != 0)
                {
                    relative << (num/denom) << endl;
                }
                ideal >> left;
                candidate >> right;
                ++total;
            }
        }
    }
    return 0;
}
