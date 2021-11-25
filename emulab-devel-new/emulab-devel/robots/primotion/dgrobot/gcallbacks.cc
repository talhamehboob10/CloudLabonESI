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

/* Garcia robot callback class methods
 *
 * Dan Flickinger
 *
 * 2004/11/16
 * 2004/11/19
 *
 */
 
#include "gcallbacks.h"

CallbackComplete::CallbackComplete(acpObject *b, grobot *g, cb_type_t cbt) {
  behavior = b;
  pgrobot = g;

  blast_status = 0x000;
  
  // get ID of current behavior
  blast_id = behavior->getNamedValue("unique-id")->getIntVal();

  this->cbt = cbt;
  
  //strcpy(lastMSG, "no messages");
  // cout << "Created Callback" << endl;
}



CallbackComplete::~CallbackComplete() {
  // cout << "Deleting callback" << endl;
  
  // send back the status message
  
  // for now, dump callback messages to stdout:
  //cout << "CB: " << blast_status << endl; 
  

}


aErr CallbackComplete::call() {
  // call completion callback
  
  blast_status = behavior->getNamedValue("completion-status")->getIntVal();
  pgrobot->setCBstatus(blast_id, blast_status, this->cbt);
}





CallbackExecute::CallbackExecute(acpObject *b, grobot *g) {
  // constructor
  
  behavior = b;
  pgrobot = g;
}



CallbackExecute::~CallbackExecute() {
  // destructor
  
  // DO WHAT?
}



aErr CallbackExecute::call() {
  // call execution callback
  blast_id = behavior->getNamedValue("unique-id")->getIntVal();
  pgrobot->setCBexec(blast_id);
  
}


