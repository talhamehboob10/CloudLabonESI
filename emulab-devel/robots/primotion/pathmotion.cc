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

/* pathmotion: garcia robot path generator
 *
 * Dan Flickinger
 *
 * 2004/10/04
 * 2004/11/17
 */

#define PATH_SIMPLE
#include "dgrobot/commotion.h"

int main(int argc, char **argv)
{ 
  // fnord!
  
//  char fileINname [64];
//  char commandIN [16];
  
  float length, radius, i_velocity, f_velocity;
  int pstatus;
  
  
  grobot robot1; 
//  ifstream fileIN;
  spathseg * pathc;

//   cout << "Cubic path generation" << endl
//        << "PATH FILE? ->" << flush;
//   cin >> fileINname;
//   
//   
//   fileIN.open(fileINname, ios::in);
//   
//   while (!(fileIN.eof())) {
//     // read file until end
//     
//     fileIN >> length >> radius >> i_velocity >> f_velocity;
//     
//     if (!(fileIN.eof())) {
      
//  while (strcmp(commandIN, "q") != 0) {
    
//    cout << "? ";
//    cin >> length >> radius >> i_velocity >> f_velocity;

  // set up segment, half circle of radius 1 m
  length = M_PI;
  radius = 1.0f;
  i_velocity = 0.0f;
  f_velocity = 0.2f;

      
  pathc = new spathseg(&robot1, length, radius, i_velocity, f_velocity);
  cout << "New path segment created" << endl;
  pstatus = pathc->execute();
  cout << "Segment executed" << endl;
      
  if (pstatus == 0) {
    // everything is GOOD
    cout << "Completed path segment " << length << "m." << endl;
  } else {
    // damn, path segment did not complete
    cout << "Path segment " << length << "m FAILED." << endl;
        
    // FIXME: do something!
        
               
        
  }
  delete pathc;
  // leave pointer hanging until next loop iteration. Woo!
    
//  }
  
  
  //fileIN.close();
  
  // set wheels to zero!
  robot1.setWheels(0.0f, 0.0f);
      
  return 0;
  
}



