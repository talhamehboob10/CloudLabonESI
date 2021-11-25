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

#include <assert.h>

#include "robotObject.h"

struct robot_data ro_data;

char *ro_status_names[ROS_MAX] = {
    "",

    "Known",
    "Unknown",
    "Started Wiggling",
    "Wiggle Queue",
    "Wiggling",
    "Lost",
};

void roInit(void)
{
    int lpc;

    for (lpc = 0; lpc < ROS_MAX; lpc++) {
	lnNewList(&ro_data.rd_lists[lpc]);
    }
}

void roMoveRobot(struct robot_object *ro, ro_status_t new_status)
{
    assert(ro != NULL);
    assert(new_status > ROS_MIN);
    assert(new_status < ROS_MAX);
    
    lnRemove(&ro->ro_link);
    lnAddTail(&ro_data.rd_lists[new_status], &ro->ro_link);
    ro->ro_status = new_status;

    switch (new_status) {
    case ROS_LOST:
	gettimeofday(&ro->ro_lost_timestamp, NULL);
	break;
    default:
	break;
    }
}

struct robot_object *roDequeueRobot(ro_status_t old_status,
				    ro_status_t new_status)
{
    struct robot_object *retval = NULL;
    
    assert(old_status > ROS_MIN);
    assert(old_status < ROS_MAX);
    assert(new_status > ROS_MIN);
    assert(new_status < ROS_MAX);

    if (!lnEmptyList(&ro_data.rd_lists[old_status])) {
	retval = (struct robot_object *)ro_data.rd_lists[old_status].lh_Head;
	roMoveRobot(retval, new_status);
    }
    
    return retval;
}

struct robot_object *roFindRobot(int id)
{
    struct robot_object *retval = NULL;

    for (retval = ro_data.rd_all;
	 (retval != NULL) && (retval->ro_id != id);
	 retval = retval->ro_next) {
    }

    return retval;
}
