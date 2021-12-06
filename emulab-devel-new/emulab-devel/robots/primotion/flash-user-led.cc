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

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>

#include "garciaUtil.hh"
#include "ledManager.hh"

static volatile int looping = 1;

static void sigquit(int signal)
{
    looping = 0;
}

static void usage(void)
{
    fprintf(stderr,
	    "usage: flash-user-led "
	    "<dot|fast-dot|dash|dash-dot|dash-dot-dot|line>\n");
}

int main(int argc, char *argv[])
{
    ledClient::lm_pattern_t lmp;
    int retval = EXIT_SUCCESS;

    if (argc != 2) {
	usage();
	
	retval = EXIT_FAILURE;
    }
    else if ((lmp = ledClient::findPattern(argv[1])) == ledClient::LMP_MAX) {
	fprintf(stderr, "error: invalid pattern - %s\n", argv[1]);
	usage();
	
	retval = EXIT_FAILURE;
    }
    else {
	acpGarcia garcia;
	aIOLib ioRef;
    
	signal(SIGQUIT, sigquit);
	signal(SIGTERM, sigquit);
	signal(SIGINT, sigquit);
	
	aIO_GetLibRef(&ioRef, NULL);
	
	if (!wait_for_brainstem_link(ioRef, garcia)) {
	    fprintf(stderr, "error: cannot establish link to robot\n");
	    
	    retval = EXIT_FAILURE;
	}
	else {
	    ledManager lm(garcia, "user-led");
	    ledClient lc(0, lmp);
	    unsigned long now;

	    lm.addClient(&lc);
	    while (looping) {
		garcia.handleCallbacks(50);
		aIO_GetMSTicks(ioRef, &now, NULL);
		lm.update(now);
	    }
	}
	
	aIO_ReleaseLibRef(ioRef, NULL);
    }
    
    return retval;
}
