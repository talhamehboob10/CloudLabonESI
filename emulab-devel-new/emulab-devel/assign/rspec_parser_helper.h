/*
 * Copyright (c) 2010 University of Utah and the Flux Group.
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
 * Helper class for the rspec parser
 */
 
#ifdef WITH_XML 
 
#ifndef __RSPEC_PARSER_HELPER_H__
#define __RSPEC_PARSER_HELPER_H__

#include "xstr.h"

#include <sstream>
#include <string>
#include <vector>
#include <xercesc/dom/DOM.hpp>

class rspec_parser_helper
{
 public:
  std::string getAttribute (const xercesc::DOMElement*, 
			    const std::string,
			    bool&);
  std::string getAttribute(const xercesc::DOMElement*, const std::string);
  bool hasAttribute (const xercesc::DOMElement*, const std::string);
  std::string readChild (const xercesc::DOMElement*, const char*, bool&);
  std::string readChild (const xercesc::DOMElement*, const char*);
  bool hasChild (const xercesc::DOMElement*, const char*);
  std::vector<xercesc::DOMElement*> 
    getChildrenByName(const xercesc::DOMElement* parent, const char* name);
  
  // Methods to convert between strings and other data types
  static std::string numToString (int num);
  static std::string numToString (double num);
  static float stringToNum (std::string str);
  
  // To determine the rspec version from the root element
  static int getRspecVersion (xercesc::DOMElement* root);

  // Converts the (hardwareType/sliverType) pair of rspec v2 to a single type
  // for assign's consumption
  static std::string convertType (std::string hwType, std::string slType);

  // Converts a single type name of the old format into a 
  // (hardwareType/sliverType) pair and then converts it into a single type
  // for assign's consumption
  static std::string convertType (std::string type);
};

#endif // __RSPEC_PARSER_HELPER_H__

#endif // WITH_XML
