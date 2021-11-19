/*
 * Copyright (c) 2003-2010 University of Utah and the Flux Group.
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
 * Contains the actual functions to do simulated annealing
 */

#ifndef __ANNEAL_H
#define __ANNEAL_H

#include "port.h"

#include <boost/graph/adjacency_list.hpp>
using namespace boost;

#include <iostream>
using namespace std;

#include <math.h>

#include "delay.h"
#include "physical.h"
#include "pclass.h"
#include "fstring.h"

// Some defaults for #defines
#ifndef NO_REVERT
#define NO_REVERT 0
#endif

#ifndef REVERT_VIOLATIONS
#define REVERT_VIOLATIONS 1
#endif

#ifndef REVERT_LAST
#define REVERT_LAST 0
#endif

#ifdef PHYS_CHAIN_LEN
#define PHYSICAL(x) x
#else
#define PHYSICAL(x) 0
#endif

/*
 * Parameters used to control annealing
 */
extern int init_temp;
extern int temp_prob;
extern float temp_stop;
extern int CYCLES;

// Initial acceptance ratio for melting
extern float X0;
extern float epsilon;
extern float delta;

// Number of runs to spend melting
extern int melt_trans;
extern int min_neighborhood_size;

extern float temp_rate;

/*
 * Globals - XXX made non-global!
 */
/* From assign.cc */
extern pclass_types type_table;
extern pclass_list pclasses;
extern pnode_pvertex_map pnode2vertex;
extern double best_score;
extern int best_violated, iters, iters_to_best;
extern bool allow_overload;

#ifdef PER_VNODE_TT
extern pclass_types vnode_type_table;
#endif

/* Decides based on the temperature if a new score should be accepted or not */
inline bool accept(double change, double temperature);

/* Find a pnode that can satisfy the give vnode */
tb_pnode *find_pnode(tb_vnode *vn);

/* The big guy! */
void anneal(bool scoring_selftest, bool check_fixed_nodes,
        double scale_neighborhood, double *initial_temperature,
        double use_connected_pnode_find);

typedef hash_map<fstring,fstring> name_name_map;
typedef slist<fstring> name_slist;

#endif
