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

/* circle: garcia robot simple circle path
 * (Tests grobot::setvPath(float, float))
 *
 * Dan Flickinger
 *
 * 2004/11/10
 * 2004/11/11
 */
 
#include "dgrobot/commotion.h"

int main(int argc, char **argv)
{
  
  // terminal setup
  struct termios old_mode;
  struct termios new_mode;

  tcgetattr(fileno(stdout),&old_mode);
  
  new_mode = old_mode;
  new_mode.c_lflag &= ~(ECHOKE | ECHOK | ECHOE | ECHO);
  new_mode.c_lflag &= ~(ICANON);
  
  tcsetattr(fileno(stdout),TCSANOW,&new_mode);
  
  setbuf(stdin,(char*)NULL);
  char keypress = '~';
  
  int status = 0;
  grobot robot1;
  
  robot1.setvPath(0.2f, 0.5f);
  robot1.sleepy();
  cout << "Set path to 1.0 m diameter circle at 0.2 m/s" << endl;
  
  do {
    robot1.sleepy();
    fread(&keypress, sizeof(char), 1, stdin);
  
    status = robot1.getGstatus();
  } while ((keypress == '~') && (status == 0));
  
  robot1.sleepy();
  cout << "Garcia status: " << status << endl;
  
  cout << "Setting wheels to zero" << endl;
  robot1.setWheels(0.0f, 0.0f);
  cout << "DONE..." << endl;
  
  robot1.sleepy();
  
  
  return 0;
}
