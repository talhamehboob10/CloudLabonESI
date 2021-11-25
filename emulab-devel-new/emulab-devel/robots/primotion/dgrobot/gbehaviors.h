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

/* Garcia robot behavior data class
 *
 * Dan Flickinger
 *
 * 2004/11/19
 * 2004/11/19
 */
 
#ifndef GBEHAVIORS_H
#define GBEHAVIORS_H

#include <string>

// shouldn't this already be defined???!!
#define aGARCIA_ERRFLAG_NORMAL		 0x0000
#define aGARCIA_ERRFLAG_STALL		 0x0001
#define aGARCIA_ERRFLAG_FRONTR_LEFT	 0x0002
#define aGARCIA_ERRFLAG_FRONTR_RIGHT 	 0x0003
#define aGARCIA_ERRFLAG_REARR_LEFT	 0x0004
#define aGARCIA_ERRFLAG_REARR_RIGHT	 0x0005
#define aGARCIA_ERRFLAG_SIDER_LEFT	 0x0008
#define aGARCIA_ERRFLAG_SIDER_RIGHT	 0x0009
#define aGARCIA_ERRFLAG_FALL_LEFT	 0x0010
#define aGARCIA_ERRFLAG_FALL_RIGHT	 0x0011
#define aGARCIA_ERRFLAG_ABORT		 0x0012
#define aGARCIA_ERRFLAG_NOTEXECUTED	 0x0013
#define aGARCIA_ERRFLAG_WONTEXECUTE	 0x0014
#define aGARCIA_ERRFLAG_BATT		 0x0020
#define aGARCIA_ERRFLAG_IRRX		 0x0040

class gbehavior;


class gbehavior {
  public:
    gbehavior();
    ~gbehavior();
    
    void getStatus(char *MSG);
    float getDisp();
    
    void setStatus(int stat);
    void setDisp(float disp);
    void setID(int ID);
    
  private:
    int b_ID;     // behavior ID
    int b_status; // behavior return status
    
    float b_disp; // behavior final displacement
};

#endif
