// coprocess.cc

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

#include <unistd.h>

#include "lib.h"
#include "coprocess.h"

using namespace std;

FileWrapper coprocess(string const & command)
{
    FileWrapper temp(popen(command.c_str(), "r+"));
    return temp;
}

int read(FileWrapper & file, int & source, int & dest, int & firstHop,
          int & distance)
{
    int count = 0;
    count += fread(&source, sizeof(source), 1, file.get());
    count += fread(&dest, sizeof(dest), 1, file.get());
    count += fread(&firstHop, sizeof(firstHop), 1, file.get());
    count += fread(&distance, sizeof(distance), 1, file.get());
    return count;
}

void write(FileWrapper & file, char command)
{
    fwrite(&command, sizeof(command), 1, file.get());
}

void write(FileWrapper & file, char command, int source, int dest, float cost)
{
    fwrite(&command, sizeof(command), 1, file.get());
    fwrite(&source, sizeof(source), 1, file.get());
    fwrite(&dest, sizeof(dest), 1, file.get());
    fwrite(&cost, sizeof(cost), 1, file.get());
}
