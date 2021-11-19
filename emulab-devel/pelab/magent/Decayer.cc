/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
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

// Decayer.cc

#include "lib.h"
#include "Decayer.h"

using namespace std;

Decayer::Decayer(int newValue, double newRate)
    : original(newValue)
    , decayed(newValue)
    , decayRate(newRate)
{
}

void Decayer::reset(int newValue)
{
    original = newValue;
    decayed = newValue;
}

int Decayer::get(void)
{
    return original;
}

void Decayer::decay(void)
{
    decayed = decayed - decayed*decayRate;
}

bool Decayer::operator<(int right) const
{
    return static_cast<int>(decayed) < right;
}

bool Decayer::operator<=(int right) const
{
    return static_cast<int>(decayed) <= right;
}

bool Decayer::operator>(int right) const
{
    return static_cast<int>(decayed) > right;
}

bool Decayer::operator>=(int right) const
{
    return static_cast<int>(decayed) >= right;
}

bool Decayer::operator==(int right) const
{
    return static_cast<int>(decayed) == right;
}

bool Decayer::operator!=(int right) const
{
    return static_cast<int>(decayed) != right;
}

bool operator<(int left, Decayer const & right)
{
    return right >= left;
}

bool operator<=(int left, Decayer const & right)
{
    return right > left;
}

bool operator>(int left, Decayer const & right)
{
    return right <= left;
}

bool operator>=(int left, Decayer const & right)
{
    return right < left;
}

bool operator==(int left, Decayer const & right)
{
    return right == left;
}

bool operator!=(int left, Decayer const & right)
{
    return right != left;
}
