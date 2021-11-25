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

/* simplepath.cc
 * methods for spathseg class; simple path segment generator
 *
 * Dan Flickinger
 *
 * 2004/11/16
 * 2004/11/16
 */
 
#include "simplepath.h"

spathseg::spathseg() {
  // default constructor
  
  pgrobot = new grobot();
  
  // pivot 360 degrees and go nowhere
  s_length = 2 * M_PI;
  s_radius = 0.0f;
  
  s_Ivelocity = 0.0f;
  s_Fvelocity = 0.0f;
}


 
spathseg::~spathseg() {
  
  delete pgrobot;
  
}



spathseg::spathseg(grobot *g,
                   float s_l,
                   float s_r,
                   float s_iv,
                   float s_fv) {
  // set up a path segment
   
  
  pgrobot = g;
  
  s_length = s_l;
  s_radius = s_r;
  
  s_Ivelocity = s_iv;
  s_Fvelocity = s_fv;

}



int spathseg::execute() {
   // execute this path segment
  
   int returnval = 0;
   int execseg = 1;
   
   float pathperc = 0.0f;    // percent of path completed
   
   float c_velocity = 0.0f; // current velocity
   
   // check the values set to determine if a
   // primitive behavior should be executed instead
   if (s_Ivelocity == 0.0f && s_Fvelocity == 0.0f) {
     if (s_radius == 0.0f) {
       // pivot segment
       pgrobot->pbPivot(s_length);
       returnval = 0; // FIXME: need better return value here
       execseg = 0;
     }
     if (fabs(s_radius) >= 100.0f) {
       // move segment
       pgrobot->pbMove(s_length);
       returnval = 0; // FIXME: need better return value here
       execseg = 0;
     }
   }
    
   
   if (execseg == 1) {
     // execute the path segment using setvPath(float, float)
        
     // reset the odometers
     pgrobot->resetPosition();
   
     // start the robot along the path segment
     while (pathperc <= 1.0f) {
       // traveled distance along arc is still less than desired
    
       // calculate the percent of the path completed
       pathperc = pgrobot->getArclen() / s_length;
     
       // calculate the current velocity and radius
       c_velocity = s_Ivelocity + pathperc * (s_Fvelocity - s_Ivelocity);
     
       // send the current velocity and radius to the robot
       pgrobot->setvPath(c_velocity, s_radius);
 
     
       returnval = pgrobot->getGstatus();
       if (returnval != 0x000) {
         // this segment failed for some reason, E-stop and get out of here
         estop();
         break;
       }
      
       // get some sleep
       pgrobot->sleepy();
     }
   }
  
  return returnval;
}
 


void spathseg::estop() {
  // immediately stop the robot
  
  pgrobot->setWheels(0.0f, 0.0f);
}


