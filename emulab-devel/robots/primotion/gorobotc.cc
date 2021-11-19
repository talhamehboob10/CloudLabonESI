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

/* gorobotc.cc
 *
 * Console application to drive robot using grobot::goto()
 *
 * Dan Flickinger
 *
 * 2004/12/08
 * 2004/12/09
 */

 
#include "dgrobot/commotion.h"


int main() {

  float dx, dy, dr;
  float dxe, dye;
  
  int quitnow = 0;
  int gstatus = 0;
  
  grobot mrrobot;
  
  
  while (quitnow == 0) {
    
    std::cout << "? " << std::flush;
    std::cin >> dx >> dy >> dr;
    
    if ((float)(dx) == 0.0f && (float)(dy) == 0.0f) {
      if ((float)(dr) == 0.0f) {
        // send an estop
        std::cout << "ESTOP" << std::endl;
        mrrobot.estop();
      } else {
        std::cout << "Quiting..." << std::endl;
        quitnow = 1;
      }
    } else {
      mrrobot.dgoto((float)(dx), (float)(dy), (float)(dr));
    
    
      // wait for moves to complete
      while (!mrrobot.garcia.getNamedValue("idle")->getBoolVal()) {
        mrrobot.sleepy();
      }
    
      // get the status
      gstatus = mrrobot.getGOTOstatus();
      mrrobot.getDisplacement(dxe, dye);
      
      std::cout << "Goto move finished with status: " << gstatus
                << std::endl
                << "(Estimated position: " << dxe << ", "
                << dye << ".)" << std::endl;
      
      
      
    }
  }
 
  return 0; 
}
