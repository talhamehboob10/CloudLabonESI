// Exception.h

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

// Exception.h defines all of the possible things that might go wrong with
// the program. Each one has a string associated with it that is printed
// to the user as output.

#ifndef EXCEPTION_H_IP_ASSIGN_1
#define EXCEPTION_H_IP_ASSIGN_1

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

// Can be thrown during IP assignment
class BitOverflowException : public StringException
{
public:
    explicit BitOverflowException(std::string const & error)
        : StringException("Too many hosts and lans: " + error)
    {
    }
};

// Can be thrown during input phase
class InvalidCharacterException : public StringException
{
public:
    explicit InvalidCharacterException(std::string const & error)
        : StringException("Invalid character(s) in line: " + error)
    {
    }
};

// Can be thrown during input phase
class MissingWeightException : public StringException
{
public:
    explicit MissingWeightException(std::string const & error)
        : StringException("Missing weight in line: " + error)
    {
    }
};

// Can be thrown during input phase
class NotEnoughNodesException : public StringException
{
public:
    explicit NotEnoughNodesException(std::string const & error)
        : StringException("Not enough nodes in line: " + error)
    {
    }
};

// Should not be thrown.
// This is deprecated and will be removed soon.
class NoHeaderException : public StringException
{
public:
    explicit NoHeaderException(std::string const & error)
        : StringException("Error Reading Header: " + error)
    {
    }
};

// Can be thrown during startup
class InvalidArgumentException : public StringException
{
public:
    explicit InvalidArgumentException(std::string const & error)
        : StringException("Invalid Argument: " + error)
    {
    }
};

// Can be thrown in various places. I put this here whenever there was
// a dangling 'else' or 'default' that should never be reached.
class ImpossibleConditionException : public StringException
{
public:
    explicit ImpossibleConditionException(std::string const & error)
        : StringException("Impossible Condition in Function: " + error)
    {
    }
};

// Can be thrown during route calculation. This is also currently what
// gets thrown in the event of a disconnected input graph.
class NoConnectionException : public StringException
{
public:
    explicit NoConnectionException(std::string const & error)
        : StringException("Oops. I tried to get a connection"
                          " which doesn't exist: " + error)
    {
    }
};

// Can be thrown during route calculation.
class NoGraphToRouteException : public StringException
{
public:
    explicit NoGraphToRouteException(std::string const & error)
        : StringException("I was asked to set up routing without a graph: "
                          + error)
    {
    }
};

#endif

