/*
 * Copyright (c) 2005-2006 University of Utah and the Flux Group.
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

#include <stdlib.h>
#include <string>

using namespace std;

#include "exceptions.h"
#include "dataqsdk.h"
#include "constants.h"


///////////////////////////////////////////////////////////////////////////////
// Implement classes to throw indicating errors
///////////////////////////////////////////////////////////////////////////////

DataqException::DataqException( long int f_errorcode )
: std::runtime_error("DataqException")
{
    errorcode = f_errorcode;
}


DataqException::~DataqException() throw()
{
}

string DataqException::what()
{
    if(		  errorcode == ENODEV ){
        msg = "DataqException: No Device Specified";
    }else if( errorcode == ENOSYS ){
        msg = "DataqException: Function not supported";
    }else if( errorcode == EBUSY ){
        msg = "DataqException: Acquiring/Busy";
    }else if( errorcode == ENOLINK  ){
        msg = "DataqException: Not Connected";
    }else if( errorcode == EINVAL   ){
        msg = "DataqException: Bad parameter pointer";
    }else if( errorcode == EBOUNDS  ){
        msg = "DataqException: Parameter value(s) out of bounds.";
    }else{
        msg = "DataqException: unknown";
    }
    return msg;
}
