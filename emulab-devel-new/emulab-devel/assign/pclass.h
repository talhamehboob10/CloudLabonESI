/*
 * Copyright (c) 2000-2010 University of Utah and the Flux Group.
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

#ifndef __PCLASS_H
#define __PCLASS_H

#include<map>

// Declared in assign.cc - indicated whether or not we should use pclasses
extern bool use_pclasses;

// tb pnode list is a data structure that acts like list but has
// O(1) removal.  It is a list of tb_pnode*.
class tb_pnodelist {
public:
  typedef list<tb_pnode*> pnode_list;
  typedef pnode_list::iterator list_iter;
  pnode_list L;
  typedef hash_map<tb_pnode*,list_iter,hashptr<tb_pnode*> > pnode_iter_map;
  pnode_iter_map D;

  list_iter push_front(tb_pnode *p) {
    L.push_front(p);
    list_iter it = L.begin();
    D[p]=it;
    return it;
  };
  list_iter push_back(tb_pnode *p) {
    L.push_back(p);
    list_iter it = L.end();
    it--;
    D[p]=it;
    return it;
  };
  int remove(tb_pnode *p) {
    if (exists(p)) {
      pnode_iter_map::iterator dit = D.find(p);
      L.erase((*dit).second);
      D.erase(dit);
      return 0;
    } else {
      return 1;
    }
  };
  int exists(tb_pnode *p) {
    return (D.find(p) != D.end());
  }
  tb_pnode *front() {
    return (L.empty() ? NULL : L.front());
  };

  int size() {
      return L.size();
  };

  friend ostream &operator<<(ostream &o, const tb_pnodelist& l)
  {
    pnode_list::const_iterator lit;
    for (lit=l.L.begin();lit!=l.L.end();++lit) {
      o << "    " << (*lit)->name << endl;
    }
    return o;
  }
};

class tb_pclass {
public:
  tb_pclass() : name(), size(0), used_members(0), disabled(false), refcount(0),
    is_dynamic(false) {;}

  typedef map<fstring,tb_pnodelist*> pclass_members_map;
  typedef hash_set<tb_pnode*,hashptr<tb_pnode*> > tb_pnodeset;
  typedef hash_map<fstring,tb_pnodeset*> pclass_members_set;

  int add_member(tb_pnode *p, bool is_own_class);

  fstring name;			// purely for debugging
  int size;
  int used_members;
  pclass_members_map members;

  bool disabled;

  // A count of how many nodes can use this pclass
  // For use with PRUNE_PCLASSES
  int refcount;

  // Is this a dynamic plcass? If false, it's a "real" one
  bool is_dynamic;

  friend ostream &operator<<(ostream &o, const tb_pclass& p)
  {
    o << p.name << " size=" << p.size <<
      " used_members=" << p.used_members << " disabled=" << p.disabled <<
      " is_dynamic=" << p.is_dynamic << "\n";
    pclass_members_map::const_iterator dit;
    for (dit=p.members.begin();dit!=p.members.end();++dit) {
      o << "  " << (*dit).first << ":\n";
      o << *((*dit).second) << endl;
    }
    o << endl;
    return o;
  }
};

typedef list<tb_pclass*> pclass_list;
typedef vector<tb_pclass*> pclass_vector;
typedef pair<int,pclass_vector*> tt_entry;
typedef hash_map<fstring,tt_entry> pclass_types;

/* Constants */
#define PCLASS_BASE_WEIGHT 1
#define PCLASS_NEIGHBOR_WEIGHT 1
#define PCLASS_UTIL_WEIGHT 1
#define PCLASS_FDS_WEIGHT 2

/* routines defined in pclass.cc */
// Sets pclasses and type_table globals -
// Takes two arguments - a physical graph, and a flag indicating whether or not
// each physical node should get its own pclass (effectively disabling
// pclasses)
int generate_pclasses(tb_pgraph &PG, bool pclass_for_each_pnode,
	bool dynamic_pclasses, bool randomize_order);

/* The following two routines sets and remove mappings in pclass
   datastructures */
int pclass_set(tb_vnode *v,tb_pnode *p);
int pclass_unset(tb_pnode *p);

// This should be called when the pnode becomes free (and pclass_unset should
// still be called first)
int pclass_reset_maps(tb_pnode *p); 

void pclass_debug();

int count_enabled_pclasses();

#endif
