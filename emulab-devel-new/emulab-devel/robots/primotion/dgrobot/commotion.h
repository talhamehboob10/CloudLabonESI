/*
 * Copyright (c) 2005 University of Utah and the Flux Group.
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

/* Garcia motion program (command and interactive mode)
 *
 * Dan Flickinger
 *
 * 2004/09/13
 * 2004/11/17
 */
 
#include <sys/time.h>
#include <unistd.h>
#include <stdio.h>

#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <string>
#include <cmath>

#include <ctype.h>
#include <termios.h>
#include <sys/types.h>
#include <sys/uio.h>


#include "acpGarcia.h"
#include "acpValue.h"


using namespace std;

#include "gcallbacks.h"
#include "grobot.h"



// path generators:
#ifdef PATH_SIMPLE
#include "simplepath.h"
#endif

#ifdef PATH_CUBIC
#include "cubicpath.h"
#endif
