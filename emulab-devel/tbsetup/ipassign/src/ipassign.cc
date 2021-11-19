// ipassign.cc

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

// For command line arguments, see README
// This program processes from stdin to stdout.
// Input and output specifications can be found in README

#include "lib.h"
#include "Exception.h"
#include "Framework.h"

using namespace std;

// constants
const int totalBits = 32;
const int prefixBits = 8;
const int postfixBits = totalBits - prefixBits;
const IPAddress prefix(10 << postfixBits);
const IPAddress prefixMask(0xFFFFFFFF << postfixBits);
const IPAddress postfixMask(0xFFFFFFFF >> prefixBits);

void usage(ostream & output);

int main(int argc, char * argv[])
{
    int errorCode = 0;

    try
    {
        Framework frame(argc, argv);
        frame.input(cin);
        frame.ipAssign();
        frame.printIP(std::cout);
    }
    catch (InvalidArgumentException const & error)
    {
        std::cerr << "ipassign: " << error.what() << std::endl;
        errorCode = 1;
        usage(std::cerr);
    }
    catch (std::exception const & error)
    {
        std::cerr << "ipassign: " << error.what() << std::endl;
        errorCode = 1;
    }

    return errorCode;
}

void usage(ostream & output)
{
    output << "Usage: See testbed/tbsetup/ipassign/README" << endl;
}
