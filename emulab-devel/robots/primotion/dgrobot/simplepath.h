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

/* simplepath.h
 * class with methods for generating simple paths
 *
 * Dan Flickinger
 * 2004/10/26
 * 2004/11/16
 */

 
#ifndef SIMPLEPATH
#define SIMPLEPATH

#include "grobot.h"

class spathseg {
   public:
     // constructors:
     spathseg();
     ~spathseg();
     spathseg(grobot *g,
              float s_l,
              float s_r,
              float s_iv,
              float s_fv);
              
     
     
     int execute();
     void estop();
     
   private:
     float s_length;   // arc length of path
     float s_radius;   // Turning radius for this segment
     
     float s_Ivelocity; // Initial forward velocity for this segment
     float s_Fvelocity; // Final forward velocity for this segment
     
     grobot *pgrobot;
};

#endif
