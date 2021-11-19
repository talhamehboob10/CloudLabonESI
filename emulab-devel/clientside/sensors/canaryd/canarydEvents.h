/*
 * Copyright (c) 2000-2004 University of Utah and the Flux Group.
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

/**
 * @file canarydEvents.h
 *
 * Header file for the event related stuff for canaryd.
 */

#ifndef CANARYD_EVENTS_H
#define CANARYD_EVENTS_H

#include "event.h"
#include "tbdefs.h"

/**
 * Initialize the canaryd connection to the Emulab event system.
 *
 * @param event_server An "elvin://" URL for the server.
 * @return True if the initialization was successful, false otherwise.
 */
int ceInitCanarydEvents(const char *event_server);

/**
 * The path to the event secret key file.
 */
#define EVENTKEYFILE "/var/emulab/boot/eventkey"

/*
 * Global data for the canaryd-related event stuff.
 *
 * ced_PidEid - The pid/eid of the experiment.  For example, "tbres/ftest".
 * ced_Handle - The handle to the event system.
 */
struct ceCanarydEventsData {
    const char *ced_PidEid;
    event_handle_t ced_Handle;
} canaryd_events_data;

/**
 * Callback for individual events.
 *
 * @param handle The event handle the event was received on.
 * @param notification The event notification itself.
 * @param data ...
 */
extern void ceEventCallback(event_handle_t handle,
			    event_notification_t notification, 
			    void *data);

#endif
