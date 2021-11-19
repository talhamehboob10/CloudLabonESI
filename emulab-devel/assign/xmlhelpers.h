/*
 * Copyright (c) 2005-2010 University of Utah and the Flux Group.
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
 * xmlhelpers.h - Classes and functions to make XML parsing a little easier
 */

#ifdef WITH_XML

#ifndef __XMLHELPERS_H
#define __XMLHELPERS_H

#include <xercesc/dom/DOM.hpp>
#include <xercesc/util/XMLString.hpp>

#include <vector>

#include "featuredesire.h"

/*
 * Convenience function - get the value of some sub-tag when we expect only
 * one. Should only be used when the schema requires exactly one child with
 * this name.
 */
const XMLCh* getChildValue(const xercesc::DOMElement* tag, const char *name);

/* This will only work if there is only one element with that tag in the parent
 * It is the callers responsibility to ensure this before calling this function
 */ 
void setChildValue(const xercesc::DOMElement* parent, 
					const char* tag, 
					const char* value);

/*
*/
xercesc::DOMElement* getNodeByName (const xercesc::DOMElement* root, const char* name);

/* Returns an element which is a child of root with name tag 
 * which has an attribute attribute_name with value attribute_value
*/
xercesc::DOMElement* getElementByAttributeValue 
								(const xercesc::DOMElement* root, 
									const char* tag, 
									const char* attribute_name, 
		 							const char* attribute_value);

/* Returns an element from roots with name tag 
 * which has an attribute attribute_name with value attribute_value
 */
xercesc::DOMElement* getElementByAttributeValue 
							(std::vector<const xercesc::DOMElement*> roots,
								const char* tag, 
								const char* attribute_name, 
								const char* attribute_value);

/* Returns a std::vector of elements which are children of root with name tag
 * and which have an attribute, attribute_name whose value is attribute_value
*/
std::vector<const xercesc::DOMElement*> getElementsByAttributeValue 
											(const xercesc::DOMElement* root, 
												const char* tag, 
												const char* attribute_name, 
												const char* attribute_value);

/* Returns a std::vector of elements which are children of root 
 * with name tag and which have an attribute, attribute_name 
*/
std::vector<xercesc::DOMElement*> getElementsHavingAttribute
										(const xercesc::DOMElement* root, 
											const char* tag, 
											const char* attribute_name);

/* This will only work if there is only one element with that tag in the root
 * It is the callers responsibility to ensure this before calling this function
 */ 
xercesc::DOMElement* getElementByTagName (const xercesc::DOMElement* root, 
										  const char* tag);

/* Returns the nth interface in a link 
  (it can be used in a node only if n is set to 0 
*/
xercesc::DOMElement* getNthInterface (const xercesc::DOMElement* root, int n);

/*
 * Convenience function - return true if the given element has a tag with the
 * given name (at least one), or false if not.
 */
bool hasChildTag(const xercesc::DOMElement* tag, const char *name);

/*
 * Parse all features and desires that are children of the given tag, and add
 * them on to the list given. Returns the number of features and desires
 * parsed.
 */
int parse_fds_xml(const xercesc::DOMElement* tag, node_fd_set *fd_set);

/*
 * Parse all features and desires that are children of the given tag, and add
 * them on to the list given. Returns the number of features and desires
 * parsed. This is especially for vnodes.
 */
int parse_fds_vnode_xml(const xercesc::DOMElement* tag, node_fd_set *fd_set);


/*
 * Get a node and interface name from an object containing an interface tag
 * (such as a source_interface tag)
 */
typedef pair<const XMLCh*, const XMLCh*> node_interface_pair;
node_interface_pair parse_interface_xml(const xercesc::DOMElement* tag);

/* 
 * Bundle the componentspec attributes together
 */
struct component_spec 
{
	string component_manager_uuid;
	string component_name;
	string component_uuid;
	string sliver_uuid;
};
/*
 * Parse the component spec attributes
 */
component_spec parse_component_spec (const xercesc::DOMElement* element);

/* 
 * Bundle the InterfaceSpec attributes together
 */
struct interface_spec 
{
	string virtual_node_id;
	string virtual_interface_id;
	string component_node_id;
	string component_interface_id;
};
/*
 * Parse the component spec attributes
 */
interface_spec parse_interface_rspec_xml (const xercesc::DOMElement* element);

/*
 * Get the _uuid or _urn attribute value based on the prefix. If neither
 * exists, return the empty string.
 */
XMLCh const * find_urn(xercesc::DOMElement const * element,
                       std::string const & prefix);

/*
 * Check if the component spec is present. 
 * We check if the aggregate UUID and the component UUID are both present
 */
bool hasComponentSpec (xercesc::DOMElement* elt);

#endif // for __XMLHELPERS_H

#endif // for WITH_XML
