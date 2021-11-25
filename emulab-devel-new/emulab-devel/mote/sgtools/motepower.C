
/*
 * Copyright (c) 2004 University of Utah and the Flux Group.
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

/*
 * motepower.C - turn the power to a mote on a stargate "on" or "off" by
 * toggling its RSTN pin
 */

#include "SGGPIO.h"

// Pin used to reset the ATMega microcontroller
#define RSTN_PIN 77

// The RSTN pin is negative logic
#define MOTE_ON 1
#define MOTE_OFF 0

void usage() {
	fprintf(stderr,"Usage: motepower <on | off | cycle>\n");
	exit(1);
}

int main(int argc, char **argv) {
    /*
     * Handle command-line argument
     */
    if (argc != 2) {
	usage();
    }

    bool turnoff = false;
    bool turnon = false;
    if (!strcmp(argv[1],"on")) {
	turnon = true;
    } else if (!strcmp(argv[1],"off")) {
	turnoff = true;
    } else if (!strcmp(argv[1],"cycle")) {
	turnon = turnoff = true;
    } else {
	usage();
    }

    /*
     * Set the pin for output
     */
    SGGPIO_PORT sggpio;
    sggpio.setDir(RSTN_PIN,1);

    /*
     * Turn off the mote, if we're supposed to
     */
    if (turnoff) {
	sggpio.setPin(RSTN_PIN,MOTE_OFF);
    }
    
    /*
     * If cycling, give it a moment
     */
    if (turnon && turnoff) {
	usleep(500 * 1000); // .5 seconds
    }

    /*
     * Turn on the mote, if we're supposed to
     */
    if (turnon) {
	sggpio.setPin(RSTN_PIN,MOTE_ON);
    }
}
