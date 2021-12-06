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

/* Callback functions for garcia robot
 *
 * Dan Flickinger
 *
 * 2004/10/04
 * 2004/11/17
 *
 */

#ifndef GCALLBACKS_H
#define GCALLBACKS_H

#include <iostream>

using namespace std;


class CallbackComplete;
class CallbackExecute;

#include "grobot.h"

// a simple callback completion class
class CallbackComplete : public acpCallback {
   public:
     CallbackComplete(acpObject *b, grobot *g, cb_type_t cbt);
     ~CallbackComplete();
  
     aErr call();
  
     int getStatus() { return blast_status; }

   private:
     acpObject *behavior;
     grobot *pgrobot;

     cb_type_t cbt;
     int blast_status; // Behavior Last _STATUS
     int blast_id;     // Behavior Last _ID
};



class CallbackExecute : public acpCallback {
  public:
    CallbackExecute(acpObject *b, grobot *g);
    ~CallbackExecute();
    
    aErr call();
    
  private:
    acpObject *behavior;
    grobot *pgrobot;

    int blast_id;     // Behavior Last _ID
    
};

#endif
