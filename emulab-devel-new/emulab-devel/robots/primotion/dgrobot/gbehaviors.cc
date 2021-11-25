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

/* Garcia robot behavior class methods
 *
 * Dan Flickinger
 *
 * 2004/11/19
 * 2004/11/19
 */
 
 
#include "gbehaviors.h"


gbehavior::gbehavior() {
  // constructor
  
  
}



gbehavior::~gbehavior() {
  // destructor
  
  
}



void gbehavior::getStatus(char *MSG) {
  // get the status of this behavior and translate to an english string
  
  if (b_status == aGARCIA_ERRFLAG_NORMAL) {
    strcpy(MSG, "no problems");
  } else if (b_status == aGARCIA_ERRFLAG_STALL) {
    strcpy(MSG, "stall condition detected");
  } else if (b_status == aGARCIA_ERRFLAG_FRONTR_LEFT) {
    strcpy(MSG, "object detected, front left IR sensor");
  } else if (b_status == aGARCIA_ERRFLAG_FRONTR_RIGHT) {
    strcpy(MSG, "object detected, front right IR sensor");
  } else if (b_status == aGARCIA_ERRFLAG_REARR_LEFT) {
    strcpy(MSG, "object detected, rear left IR sensor");
  } else if (b_status == aGARCIA_ERRFLAG_REARR_RIGHT) {
    strcpy(MSG, "object detected, rear right IR sensor");
  } else if (b_status == aGARCIA_ERRFLAG_SIDER_LEFT) {
    strcpy(MSG, "object detected, left side IR sensor");
  } else if (b_status == aGARCIA_ERRFLAG_SIDER_RIGHT) {
    strcpy(MSG, "object detected, right side IR sensor");
  } else if (b_status == aGARCIA_ERRFLAG_FALL_LEFT) {
    strcpy(MSG, "drop-off detected, front left side");
  } else if (b_status == aGARCIA_ERRFLAG_FALL_RIGHT) {
    strcpy(MSG, "drop-off detected, front right side");
  } else if (b_status == aGARCIA_ERRFLAG_ABORT) {
    strcpy(MSG, "aborted");
  } else if (b_status == aGARCIA_ERRFLAG_NOTEXECUTED) {
    strcpy(MSG, "not executed for some stupid reason");
  } else if (b_status == aGARCIA_ERRFLAG_WONTEXECUTE) {
    strcpy(MSG, "will not execute: bitching about something");
  } else if (b_status == aGARCIA_ERRFLAG_BATT) {
    strcpy(MSG, "LOW BATTERY: robot cry");
  } else if (b_status == aGARCIA_ERRFLAG_IRRX) {
    strcpy(MSG, "IR receiver override");
  } else {
    strcpy(MSG, "NO STATUS");
  }
  
  

}



float gbehavior::getDisp() {
  // get final displacement for this behavior
  return b_disp;
}
  


void gbehavior::setStatus(int stat) {
  // set the status for this behavior
  b_status = stat;
}



void gbehavior::setDisp(float disp) {
  // set the final displacement for this behavior
  b_disp = disp;
}



void gbehavior::setID(int ID) {
  // set the ID for this behavior
  b_ID = ID;
}


