/*
 * Copyright (c) 2000-2007 University of Utah and the Flux Group.
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

#ifndef __VCLASS_H
#define __VCLASS_H

#include "port.h"
#include "fstring.h"

#include <iostream>
using namespace std;

// tb_vclass represents a virtual equivalence class.  The main purpose
// of the code here is to monitor which members of the class are being
// used, what types that are being used as, and calculating the
// appropriate score changes.  Each vclass gives some contribution to
// the score and as nodes are assigned and unassigned this score changes.

// The membership of nodes is not stored here.  Rather each vnode
// stores which vclass it belongs to.  This class is more abstract and
// represents the scoring model.

class tb_vclass {
public:
  tb_vclass(fstring n,double w) : name(n), weight(w), score(0) {;}

  typedef hash_map<fstring,int> members_map;   
    
  void add_type(fstring type);	// Add a member of a certain type to the
				// vclass

  bool has_type(fstring type) const; // Does the vclass contain the given type?

  bool empty() const;                // True if no vnodes use this vlcass

  // The next two routines report the *change* in score.  The score
  // for the vclass as a whole is 0 if all nodes are of the dominant
  // type and the weight if they aren't.
  double assign_node(fstring type);
  double unassign_node(fstring type);

  // Semi randomly choose a type from a vclass.
  fstring choose_type() const;

  friend ostream &operator<<(ostream &o, const tb_vclass& c)
  {
    o << "vclass: " << c.name << " dominant=" << c.dominant <<
      " weight=" << c.weight << " score=" << c.score << endl;
    o << "  ";
    for (members_map::const_iterator dit=c.members.begin();
	 dit!=c.members.end();++dit) {
      o << (*dit).first << ":" << (*dit).second << " ";
    }
    o << endl;
    return o;
  }
  
  // Get the list of members
  const members_map &get_members() const {
    return(members);
  }
  
  // Just get the name
  fstring get_name() const {
    return(name);
  }
  
  // Get the name of the dominant type
  fstring get_dominant() const {
    return(dominant);
  }

private:
      
  fstring name;			// Name of the vclass

  members_map members;		// Maps type to number of members of that
				// type.
  
  double weight;		// Weight of class
  double score;			// the current score of the vclass
  
  fstring dominant;		// Current dominant type

};

typedef hash_map<fstring,tb_vclass*> name_vclass_map;
extern name_vclass_map vclass_map;

#endif
