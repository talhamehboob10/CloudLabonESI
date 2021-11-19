/*
 * Copyright (c) 2000-2014 University of Utah and the Flux Group.
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

int	hashmap_blocksize(void);
void	hashmap_update_chunk(uint32_t, uint32_t, int);
int	hashmap_compute_delta(struct range *, char *, int, u_int32_t, char *,
			      struct range **);
int	hashmap_write_hashfile(char *, char *);
void	hashmap_dump_stats(int pnum);
