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

#ifndef __ANNOTATE_RSPEC_V2_H
#define __ANNOTATE_RSPEC_V2_H

#include "annotate.h"
#include "annotate_rspec.h"

#include <list>
#include <map>
#include <set>
#include <utility>
#include <string>

#include <xercesc/dom/DOM.hpp>

class annotate_rspec_v2 : public annotate_rspec
{
 private:
  // Enumeration of which interface in a hop 
  // is an interface to a link end point
  enum endpoint_interface_enum { NEITHER, SOURCE, DESTINATION, BOTH };
  std::map< std::string, std::set<std::string> > lan_links_map;

  std::map< std::string, std::string >* vInterfaceMap;
  std::map< std::string, std::string >* pInterfaceMap;
  
 public:
  annotate_rspec_v2 ();
  ~annotate_rspec_v2 () { ; }
  
  // Annotates nodes and direct links in the rspec
  void annotate_element(const char* v_name, const char* p_name);
  
  // Annotates intraswitch and interswitch links in the rspec
  void annotate_element(const char* v_name, 
			std::list<const char*>* links);
  
  // Annotate a trivial link
  void annotate_element(const char* v_name);
  
  // Annotates an interface element on a link
  void annotate_interface (const xercesc::DOMElement* plink, 
			   const xercesc::DOMElement* vlink, 
			   int interface_number,
			   bool is_trivial_link);
  
  // Annotates an interface element on a non-trivial link
  void annotate_interface (const xercesc::DOMElement* plink, 
			   const xercesc::DOMElement* vlink, 
			   int interface_number);
  
  // Annotates an interface element on a trivial link
  void annotate_interface (const xercesc::DOMElement* vlink,
			   int interface_number);
  
  // Creates a hop from a switch till the next end point. 
  // Adds the hop to the vlink
  // Returns the hop element that was created
  xercesc::DOMElement* 
    create_component_hop (const xercesc::DOMElement* plink, 
			  xercesc::DOMElement* vlink, 
			  int endpoint_interface, 
			  const xercesc::DOMElement* prev_hop);
  
  // Creates a component_hop for a trivial link
  // Adds the hop to the vlink
  // Returns the hop element that was created
  xercesc::DOMElement* create_component_hop (xercesc::DOMElement* vlink);
  
  // Finds the next link in the path returned by assign
  xercesc::DOMElement* find_next_link_in_path 
    (xercesc::DOMElement *prev, 
     std::list<const char*>* links);
  
  // Copies the component spec from the source to the destination
  void copy_component_spec(const xercesc::DOMElement* src, 
			   xercesc::DOMElement* dst);
  
  // Copies the component hop from the auto-generated link 
  // to the requested link
  void copy_component_hop(xercesc::DOMElement* requested_link, 
			  xercesc::DOMElement* component_hop);
  
  // Checks if the link contains an interface with 
  // virtual_interface_id = id
  bool has_interface_with_id (std::string link_id, std::string id);
  
  // Removes all extra tags and generated elements from the XML document
  void cleanup ();
  
  // Checks whether an element of type tag 
  // with attr_name = attr_value is a generated element
  bool is_generated_element (const char* tag, 
			     const char* attr_name, 
			     const char* attr_value);

  // Given an interface Id, returns the node on which the interface is present
  std::string lookupIface (std::map<std::string, std::string>* map,
			   std::string ifaceId, bool&);

  // Returns the interface on the physical link
  // which is declared on the physical node with component_id, physNodeId
  const xercesc::DOMElement* 
    getIfaceOnNode(const xercesc::DOMElement* plink, std::string physNodeId);

  // Retuns the component id of the nth interface of a link
  std::string getNthInterface (const xercesc::DOMElement* link, int n);

  // Annotates the end point of a link
  bool annotate_endpoint(xercesc::DOMElement* iface, std::string virtId);

  // Extracts the short interface name from the interface URN
  std::string getShortInterfaceName (std::string interfaceURN);

  // Adds a fixed interface element to an interface
  void addFixedInterface(xercesc::DOMElement* interface,std::string shortname);

  // Orders the links in the specified list of links from head to tail
  // The first element in the list MUST be the head
  // WARNING: This will destroy in the input list
  std::list<const char*>* reorderLinks (std::list<const char*>* links);
};

#endif //for __ANNOTATE_RSPEC_H

#endif // for WITH_XML
