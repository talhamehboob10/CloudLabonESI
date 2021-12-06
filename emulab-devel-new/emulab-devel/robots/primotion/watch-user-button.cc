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
#include "buttonManager.hh"

class myButtonCallback : public buttonCallback
{

public:
    
    virtual bool shortClick(acpGarcia &garcia, unsigned long now)
    {
	printf("shortClick(%ld)\n", now);
	return true;
    };

    virtual bool commandMode(acpGarcia &garcia, unsigned long now, bool on)
    {
	printf("commandMode(%ld, %d)\n", now, on);
	return true;
    };

    virtual bool shortCommandClick(acpGarcia &garcia, unsigned long now)
    {
	printf("shortCommandClick(%ld)\n", now);
	return true;
    };

    virtual bool longCommandClick(acpGarcia &garcia, unsigned long now)
    {
	printf("longCommandClick(%ld)\n", now);
	return true;
    };
    
};

static volatile int looping = 1;

static void sigquit(int signal)
{
    looping = 0;
}

int main(int argc, char *argv[])
{
    int retval = EXIT_SUCCESS;
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
	buttonManager bm(garcia, "user-button");
	unsigned long now;

	bm.setCallback(new myButtonCallback());
	while (looping) {
	    garcia.handleCallbacks(50);
	    aIO_GetMSTicks(ioRef, &now, NULL);
	    bm.update(now);
	}
    }
    
    aIO_ReleaseLibRef(ioRef, NULL);
    
    return retval;
}
