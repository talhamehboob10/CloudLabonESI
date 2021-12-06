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

#include <memory>
#include <string>
#include <errno.h>

#include "pistream.h"
#include "postream.h"

class FileT
{
public:
    FileT(int newInput, int newOutput, int newError)
        : inDes(newInput)
        , in(newInput)
        , outDes(newOutput)
        , out(newOutput)
        , errDes(newError)
        , err(newError)
    {
    }

    ~FileT()
    {
        if (inDes != -1)
        {
            close(inDes);
        }
        if (outDes != -1)
        {
            close(outDes);
        }
        if (errDes != -1)
        {
            close(errDes);
        }
    }

    void closeIn(void)
    {
        if (inDes != -1)
        {
            close(inDes);
            inDes = -1;
        }
    }

    void closeOut(void)
    {
        if (outDes != -1)
        {
            close(outDes);
            outDes = -1;
        }
    }

    void closeErr(void)
    {
        if (errDes != -1)
        {
            close(errDes);
            errDes = -1;
        }
    }

    std::ostream & input(void) const
    {
        if (inDes == -1)
        {
            cerr << "Error: input used after closing" << endl;
            throw;
        }
        return in;
    }

    std::istream & output(void) const
    {
        if (outDes == -1)
        {
            cerr << "Error: output used after closing" << endl;
            throw;
        }
        return out;
    }

    std::istream & error(void) const
    {
        if (errDes == -1)
        {
            cerr << "Error: error used after closing" << endl;
        }
        return err;
    }
private:
    FileT();
    FileT(FileT const &);
    FileT & operator=(FileT const &) { return *this; }
private:
    int inDes;
    int outDes;
    int errDes;
    mutable postream in;
    mutable pistream out;
    mutable pistream err;
};

std::auto_ptr<FileT> coprocess(char const * path, char * const argv[],
                               char * const envp[]);

#endif
