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

#ifndef __EMCD_H__
#define __EMCD_H__

#include "mtp.h"

enum {
  ERB_HAS_GOAL,
};

enum {
  ERF_HAS_GOAL = (1L << ERB_HAS_GOAL),
};

struct emc_robot_config {
  int id;
  char *hostname;
  char *vname;
  struct in_addr ia;
  int token;
  float init_x;
  float init_y;
  float init_theta;
  struct robot_position last_update_pos;
  struct robot_position last_goal_pos;
  unsigned long flags;
};

struct rmc_client {
  mtp_handle_t handle;
  struct robot_list *position_list;
};

struct vmc_client {
  mtp_handle_t handle;
  struct robot_list *position_list;
};

#define EMC_SERVER_PORT 2525

#define EMC_UPDATE_HZ (333)

#endif
