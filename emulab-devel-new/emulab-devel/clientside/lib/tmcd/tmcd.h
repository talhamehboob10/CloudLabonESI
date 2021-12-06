/*
 * Copyright (c) 2000-2019 University of Utah and the Flux Group.
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

#define TBSERVER_PORT		7777
#define TBSERVER_PORT2		14447
#define MYBUFSIZE		2048
#define BOSSNODE_FILENAME	"bossnode"
#define MAXTMCDPACKET		0x8000	/* Allow for big console logs */

/*
 * As the tmcd changes, incompatable changes with older version of
 * the software cause problems. Starting with version 3, the client
 * will tell tmcd what version they are. If no version is included,
 * assume its DEFAULT_VERSION.
 *
 * Be sure to update the versions as the TMCD changes. Both the
 * tmcc and tmcd have CURRENT_VERSION compiled in, so be sure to
 * install new versions of each binary when the current version
 * changes. libsetup.pm module also encodes a current version, so be
 * sure to change it there too!
 *
 * Note, this is assumed to be an integer. No need for 3.23.479 ...
 * NB: See ron/libsetup.pm. That is version 4! I'll merge that in. 
 *
 * IMPORTANT NOTE: if you change CURRENT_VERSION, you must also change
 * it in clientside/tmcc/common/libsetup.pm!
 */
#define DEFAULT_VERSION		2
#define CURRENT_VERSION		44
