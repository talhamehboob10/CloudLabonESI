/*
 * Copyright (c) 2013-2014 University of Utah and the Flux Group.
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

/* Blockstore subsystem definitions */

#ifndef BSDEFS_H
#define BSDEFS_H

#include "tbdefs.h"

#define BS_VNODE_TYPE   "blockstore"

/* Blockstore classes */
#define BS_CLASS_SAN    "SAN"
#define BS_CLASS_LOCAL  "local"

/* Blockstore protocols (a.k.a. bus type) */
#define BS_PROTO_ISCSI  "iSCSI"
#define BS_PROTO_SCSI   "SCSI"
#define BS_PROTO_SAS    "SAS"

/* Definitions related to iSCSI */
#ifndef BS_IQN_PREFIX
#define BS_IQN_PREFIX   "iqn.2000-10.net.emulab"
#endif
#define BS_IQN_MAXSIZE  sizeof(BS_IQN_PREFIX) + TBDB_FLEN_PID + \
	                TBDB_FLEN_EID + TBDB_FLEN_BSVOL

#define BS_PERMS_ISCSI_RO  "RO" /* read/write */
#define BS_PERMS_ISCSI_RW  "RW" /* read/write */
#define BS_PERMS_ISCSI_DEF BS_PERMS_ISCSI_RW

/* Local placement directives */
#define BS_PLACEMENT_ANY    "ANY"
#define BS_PLACEMENT_SYSVOL "SYSVOL"
#define BS_PLACEMENT_NONSYS "NONSYSVOL"
#define BS_PLACEMENT_DEF    BS_PLACEMENT_ANY

#endif /* BSDEFS_H */
