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

/* This is ugly, but we only really need this file if we are building with XML support */

#ifdef WITH_XML

#ifndef __ANNOTATE_VTOP_H
#define __ANNOTATE_VTOP_H

#include "annotate.h"

#include <list>
#include <map>
#include <utility>
#include <string>

#include <xercesc/dom/DOM.hpp>

class annotate_vtop : public annotate
{
	private:
		// Enumeration of which interface in a hop is an interface to a link end point
		enum endpoint_interface_enum { NEITHER, SOURCE, DESTINATION, BOTH };
	
	public:
		annotate_vtop ();
		~annotate_vtop () { ; }
		
		// Annotates nodes and direct links in the rspec
		void annotate_element(const char* v_name, const char* p_name);
	
		// Annotates intraswitch and interswitch links in the rspec
		void annotate_element(const char* v_name, std::list<const char*>* links);
	
		// Annotates an interface element on a link
		void annotate_interface (const xercesc::DOMElement* plink, xercesc::DOMElement* vlink, const char* interface_type);

		// Creates a hop from a switch till the next end point. Adds the hop to the vlink and returns the hop element that was created
		xercesc::DOMElement* create_component_hop (const xercesc::DOMElement* plink, xercesc::DOMElement* vlink, int endpoint_interface, const xercesc::DOMElement* prev_component_hop);
			
		// If the interface is the end point of a link/path, add an additional attribute to it
		void set_interface_as_link_endpoint (xercesc::DOMElement* interface, const xercesc::DOMElement* vlink_interface);
	
		// Finds the next link in the path returned by assign
		xercesc::DOMElement* find_next_link_in_path (xercesc::DOMElement *prev, std::list<const char*>* links);
		
		// Sets the attributes of an interface element in the component hop using the corresponding physical interface
		void set_component_hop_interface (xercesc::DOMElement* hop_interface, const xercesc::DOMElement* physical_interface);
};

#endif // for __ANNOTATE_VTOP_H

#endif // for WITH_XML
