// Exception.h

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

// Exception.h defines all of the possible things that might go wrong with
// the program. Each one has a string associated with it that is printed
// to the user as output.

#ifndef EXCEPTION_H_IP_ASSIGN_1
#define EXCEPTION_H_IP_ASSIGN_1

#include <exception>

class StringException : public std::exception
{
public:
    explicit StringException(std::string const & error)
        : message(error)
    {
    }
    virtual ~StringException() throw() {}
    virtual char const * what() const throw()
    {
        return message.c_str();
    }
    virtual void addToMessage(char const * addend)
    {
        message += addend;
    }
    virtual void addToMessage(std::string const & addend)
    {
        addToMessage(addend.c_str());
    }
private:
    std::string message;
};

class InvalidArgumentException : public StringException
{
public:
    explicit InvalidArgumentException(std::string const & error)
        : StringException("Invalid Argument: " + error)
    {
    }
    virtual ~InvalidArgumentException() throw() {}
};

#endif

