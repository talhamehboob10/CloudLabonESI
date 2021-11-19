/*
 * Copyright (c) 2005, 2006 University of Utah and the Flux Group.
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

#ifndef _vmcd_h
#define _vmcd_h

#include "listNode.h"

struct vmc_client {
    /** Our connection to the vmc-client. */
    mtp_handle_t vc_handle;

    /** The current frame for this camera. */
    struct lnMinList vc_frame;
    /** The last frame received from this camera. */
    struct lnMinList vc_last_frame;
    /** Frame count for this camera so we can detect when they fall behind. */
    unsigned long long vc_frame_count;

    /** The host where the vmc-client is running. */
    char *vc_hostname;
    /** The port the vmc-client is listening on. */
    int vc_port;

    /**
     * The bounds for this camera.  These values are detected automatically as
     * objects move around in the field.
     */
    float vc_left;
    float vc_right;
    float vc_top;
    float vc_bottom;
};

/**
 * Version information.
 */
extern char build_info[];

#endif
