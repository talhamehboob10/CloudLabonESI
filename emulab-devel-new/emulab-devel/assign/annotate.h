/*
 * Copyright (c) 2008-2010 University of Utah and the Flux Group.
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
 * Base class for the annotater. 
 */

#ifdef WITH_XML

#ifndef __ANNOTATE_H

#define __ANNOTATE_H

#include <utility>
#include <string>
#include <list>
#include <map>

#include <xercesc/dom/DOM.hpp>

class annotate
{
 protected: 
  xercesc::DOMDocument* document;
  xercesc::DOMElement* physical_root;
  xercesc::DOMElement* virtual_root;
  std::map<std::string, xercesc::DOMElement*> *physical_elements;
  
 public:
  // Annotates nodes and direct links in the rspec
  virtual void annotate_element(const char* v_name, const char* p_name) = 0;
  
  // Annotates intraswitch and interswitch links in the rspec
  virtual void annotate_element(const char* v_name, 
				std::list<const char*>* links) = 0;
  
  // Creates a hop from a switch till the next end point. 
  // Adds the hop to the vlink and returns the hop element that was created
  virtual xercesc::DOMElement* 
    create_component_hop (const xercesc::DOMElement* plink, 
			  xercesc::DOMElement* vlink, 
			  int endpoint_interface, 
			  const xercesc::DOMElement* prev_component_hop) = 0;
  
  // Finds the next link in the path returned by assign
  virtual xercesc::DOMElement* 
    find_next_link_in_path (xercesc::DOMElement *prev, 
			    std::list<const char*>* links) = 0;
  
  // Writes the annotated xml to disk
  void write_annotated_file(const char* filename);

  // Writes an XML element to a string
  std::string printXML (const xercesc::DOMElement* tag);
};

#endif // for __ANNOTATE_H

#endif // for WITH_XML
