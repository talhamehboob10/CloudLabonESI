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

/**
 * @file multi_path.c
 *
 * Path planning testing tool that has multiple obstacles.
 *
 * @see test_path.c
 */

/**
 * The bounds of the area to use for planning.
 */
static struct box bounds[] = {
    { 0, 0, 10, 10 },
};

/**
 * The set of obstacles in the area.
 */
static struct obstacle_config obstacles[] = {
    { .id = 1, .xmin = 2.25, .ymin = 4.75, .xmax = 2.75, .ymax = 5.25 },
    { .id = 2, .xmin = 2.50, .ymin = 3.25, .xmax = 3.25, .ymax = 6.75 },
    { .id = 3, .xmin = 7.25, .ymin = 3.25, .xmax = 7.75, .ymax = 6.75 },
    { .id = 0 },
};

/**
 * The set of robots in the area.
 */
static struct robot_config robots[] = {
    { 1, "garcia1" },
};
