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

//#include "lib.h"
#include "coprocess.h"

// TODO: Make sure that the pipes are properly closed in the case of
// error.
auto_ptr<FileT> coprocess(char const * path, char * const argv[],
                          char * const envp[])
{
    auto_ptr<FileT> file;
    // child_stdin[0] = stdin for child
    // child_stdin[1] = write end for parent
    int child_stdin[2] = {-1, -1};

    // child_stdout[0] = read end for parent
    // child_stdout[1] = stdout for child
    int child_stdout[2] = {-1, -1};

    // child_stderr[0] = read end for parent
    // child_stderr[1] = stderr for child
    int child_stderr[2] = {-1, -1};

    int error = 0;
    error = pipe(child_stdin);
    if (error == -1)
    {
        cerr << "Failed to open pipe child_stdin: " << strerror(errno)
             << endl;
        throw;
    }
    error = pipe(child_stdout);
    if (error == -1)
    {
        cerr << "Failed to open pipe for child_stdout: " << strerror(errno)
             << endl;
        throw;
    }
    error = pipe(child_stderr);
    if (error == -1)
    {
        cerr << "Failed to open pipe child_stderr: " << strerror(errno)
             << endl;
        throw;
    }

    error = fork();

    if (error == 0)
    {
        // child
        error = dup2(child_stdin[0], fileno(stdin));
        if (error == -1)
        {
            cerr << "Failed to dup stdin: " << strerror(errno) << endl;
            _exit(1);
        }
        error = close(child_stdin[0]);
        if (error == -1)
        {
            cerr << "Failed to close child_stdin[0]: " << strerror(errno)
                 << endl;
            _exit(1);
        }
        error = close(child_stdin[1]);
        if (error == -1)
        {
            cerr << "Failed to close child_stdin[1]: " << strerror(errno)
                 << endl;
            _exit(1);
        }
        error = dup2(child_stdout[1], fileno(stdout));
        if (error == -1)
        {
            cerr << "Failed to dup stdout: " << strerror(errno) << endl;
            _exit(1);
        }
        error = close(child_stdout[0]);
        if (error == -1)
        {
            cerr << "Failed to close child_stdout[0]: " << strerror(errno)
                 << endl;
            _exit(1);
        }
        error = close(child_stdout[1]);
        if (error == -1)
        {
            cerr << "Failed to close child_stdout[1]: " << strerror(errno)
                 << endl;
            _exit(1);
        }
        error = dup2(child_stderr[1], fileno(stderr));
        if (error == -1)
        {
            cerr << "Failed to dup stderr" << strerror(errno) << endl;
            _exit(1);
        }
        error = close(child_stderr[0]);
        if (error == -1)
        {
            cerr << "Failed to close child_stderr[0]: " << strerror(errno)
                 << endl;
            _exit(1);
        }
        error = close(child_stderr[1]);
        if (error == -1)
        {
            cerr << "Failed to close child_stderr[1]: " << strerror(errno)
                 << endl;
            _exit(1);
        }
        error = execve(path, argv, envp);
        cerr << "Failed to execve: " << strerror(errno) << endl;
        _exit(1);
    }
    else if (error > 0)
    {
        // parent
        file.reset(new FileT(child_stdin[1], child_stdout[0],
                             child_stderr[0]));
        close(child_stdin[0]);
        close(child_stdout[1]);
        close(child_stderr[1]);
    }
    else
    {
        // error
        cerr << "Failed to fork properly: " << strerror(errno) << endl;
        throw;
    }
    return file;
}
