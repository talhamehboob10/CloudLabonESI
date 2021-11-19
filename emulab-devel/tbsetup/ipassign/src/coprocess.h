// coprocess.h

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

#ifndef COPROCESS_H_IP_ASSIGN_2
#define COPROCESS_H_IP_ASSIGN_2

class FileWrapper
{
public:
    FileWrapper(FILE * newData = NULL) : data(newData)
    {
    }

    ~FileWrapper()
    {
        if (data != NULL)
        {
            pclose(data);
        }
    }

    FileWrapper(FileWrapper & right) : data(right.data)
    {
        right.data = NULL;
    }

    FileWrapper & operator=(FileWrapper & right)
    {
        FileWrapper temp(right);
        std::swap(data, temp.data);
        return *this;
    }

    void clear(void)
    {
        data = NULL;
    }

    FILE * get(void)
    {
        return data;
    }

    void reset(FILE * newData)
    {
        if (data)
        {
            pclose(data);
        }
        data = newData;
    }

    FILE * release(void)
    {
        FILE * result = data;
        data = NULL;
        return result;
    }
private:
    FILE * data;
};

FileWrapper coprocess(std::string const & command);
int read(FileWrapper & file, int & source, int & dest, int & firstHop,
          int & distance);
void write(FileWrapper & file, char command);
void write(FileWrapper & file, char command, int source, int dest, float cost);

#endif


