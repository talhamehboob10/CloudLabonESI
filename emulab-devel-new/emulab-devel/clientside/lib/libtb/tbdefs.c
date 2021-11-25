/*
 * Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
 *
 */
#include <string.h>
#include "tbdefs.h"

char *tbdb_objecttypes[] = {
	TBDB_OBJECTTYPE_TESTBED,
	TBDB_OBJECTTYPE_STATE,
	TBDB_OBJECTTYPE_OPMODE,
	TBDB_OBJECTTYPE_LINK,
	TBDB_OBJECTTYPE_TRAFGEN,
	TBDB_OBJECTTYPE_TIME,
	TBDB_OBJECTTYPE_PROGRAM,
	TBDB_OBJECTTYPE_FRISBEE,
	TBDB_OBJECTTYPE_SIMULATOR,
	TBDB_OBJECTTYPE_LINKTEST,
	TBDB_OBJECTTYPE_NSE,
        TBDB_OBJECTTYPE_CANARYD,
        TBDB_OBJECTTYPE_NODE,
        TBDB_OBJECTTYPE_GROUP,
        TBDB_OBJECTTYPE_TIMELINE,
        TBDB_OBJECTTYPE_SEQUENCE,
        TBDB_OBJECTTYPE_CONSOLE,
        TBDB_OBJECTTYPE_TOPOGRAPHY,
        TBDB_OBJECTTYPE_LINKTRACE,
        TBDB_OBJECTTYPE_EVPROXY,
        TBDB_OBJECTTYPE_BGMON,
        TBDB_OBJECTTYPE_DISK,
	TBDB_OBJECTTYPE_BSTORE,
	/*
	 * NOTE: Add the object type and any events that send back COMPLETEs to
	 * the objtype2complete array in event-sched.c:sends_complete().
	 */
	0,
};

char *tbdb_eventtypes[] = {
	TBDB_EVENTTYPE_START,
	TBDB_EVENTTYPE_STOP,
	TBDB_EVENTTYPE_KILL,
	TBDB_EVENTTYPE_ISUP,
	TBDB_EVENTTYPE_REBOOT,
	TBDB_EVENTTYPE_UP,
	TBDB_EVENTTYPE_DOWN,
	TBDB_EVENTTYPE_UPDATE,
	TBDB_EVENTTYPE_MODIFY,
	TBDB_EVENTTYPE_SET,
	TBDB_EVENTTYPE_RESET,
	TBDB_EVENTTYPE_HALT,
	TBDB_EVENTTYPE_SWAPOUT,
	TBDB_EVENTTYPE_NSESWAP,
	TBDB_EVENTTYPE_NSEEVENT,
        TBDB_EVENTTYPE_REPORT,
        TBDB_EVENTTYPE_ALERT,
        TBDB_EVENTTYPE_SETDEST,
        TBDB_EVENTTYPE_SNAPSHOT,
        TBDB_EVENTTYPE_RELOAD,
        TBDB_EVENTTYPE_COMPLETE,
        TBDB_EVENTTYPE_CLEAR,
        TBDB_EVENTTYPE_DEBUG,
        TBDB_EVENTTYPE_LOG,
	TBDB_EVENTTYPE_MESSAGE,
	TBDB_EVENTTYPE_RUN,
	TBDB_EVENTTYPE_CREATE,
	TBDB_EVENTTYPE_STOPRUN,
        TBDB_NODESTATE_ISUP, 
        TBDB_NODESTATE_REBOOTED, 
        TBDB_NODESTATE_REBOOTING, 
        TBDB_NODESTATE_SHUTDOWN, 
        TBDB_NODESTATE_BOOTING, 
        TBDB_NODESTATE_TBSETUP, 
        TBDB_NODESTATE_RELOADSETUP, 
        TBDB_NODESTATE_RELOADING, 
        TBDB_NODESTATE_RELOADDONE, 
        TBDB_NODESTATE_RELOADDONE_V2, 
        TBDB_NODESTATE_UNKNOWN, 
        TBDB_NODEOPMODE_NORMAL, 
        TBDB_NODEOPMODE_DELAYING, 
        TBDB_NODEOPMODE_UNKNOWNOS, 
        TBDB_NODEOPMODE_RELOADING, 
        TBDB_NODEOPMODE_NORMALv1, 
        TBDB_NODEOPMODE_MINIMAL, 
        TBDB_NODEOPMODE_RELOAD, 
        TBDB_NODEOPMODE_DELAY, 
        TBDB_NODEOPMODE_BOOTWHAT, 
        TBDB_NODEOPMODE_UNKNOWN, 
        TBDB_TBCONTROL_RESET, 
        TBDB_TBCONTROL_RELOADDONE, 
        TBDB_TBCONTROL_RELOADDONE_V2, 
        TBDB_TBCONTROL_TIMEOUT, 
    	0,
};

/*
 * Check that events are legal.
 */
int
tbdb_validobjecttype(char *foo)
{
	char	**bp = tbdb_objecttypes;

	while (*bp) {
		if (!strcmp(*bp, foo))
			return 1;
		bp++;
	}
	return 0;
}

int
tbdb_valideventtype(char *foo)
{
	char	**bp = tbdb_eventtypes;

	while (*bp) {
		if (!strcmp(*bp, foo))
			return 1;
		bp++;
	}
	return 0;
}

