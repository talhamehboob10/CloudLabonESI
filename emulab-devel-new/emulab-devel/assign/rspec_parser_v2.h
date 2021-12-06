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
 * Parser class for rspec version 2.0
 */
 
#ifdef WITH_XML 
 
#ifndef __RSPEC_PARSER_V2_H__
#define __RSPEC_PARSER_V2_H__

#include "rspec_parser.h"

class rspec_parser_v2 : public rspec_parser
{
 private:
  
 protected:
  std::map<std::string, std::string> ifacesSeen;
  struct link_interface getIface (const xercesc::DOMElement*);
  
 public:
  rspec_parser_v2 (int type) : rspec_parser (type) { ; }
  // Reads the interfaces on a link		
  std::vector< struct link_interface >
    readLinkInterface (const xercesc::DOMElement*, int&);
  
  struct link_characteristics 
    readLinkCharacteristics (const xercesc::DOMElement*, int&,
			     int defaultBandwidth = -1, 
			     int unlimitedBandwidth = -1);
  
  std::vector<struct node_type> 
    readNodeTypes (const xercesc::DOMElement*, int& typeCount, 
		   int unlimitedSlots);
  
  map< pair<string, string>, pair<string, string> >
    readInterfacesOnNode (const xercesc::DOMElement* node, 
			  bool& allUnique);

  std::string readAvailable(const xercesc::DOMElement* node, bool& hasTag);

  std::vector<struct link_type> 
    readLinkTypes (const xercesc::DOMElement* link, int& typeCount);

  std::vector<struct rspec_emulab_extension::type_limit>
    readTypeLimits(const xercesc::DOMElement* tag, int& count);

  std::vector<struct rspec_emulab_extension::fd>
    readFeaturesDesires(const xercesc::DOMElement* tag, int& count);

  std::vector<struct rspec_emulab_extension::vclass>
    readVClasses (const xercesc::DOMElement* tag);
  std::string readSubnodeOf (const xercesc::DOMElement* tag, bool&, int&);
  bool readDisallowTrivialMix (const xercesc::DOMElement* tag);
  bool readUnique (const xercesc::DOMElement* tag);
  int readTrivialBandwidth (const xercesc::DOMElement* tag, bool&);
  std::string readHintTo (const xercesc::DOMElement* tag, bool&);
  bool readNoDelay (const xercesc::DOMElement* tag);
  bool readTrivialOk (const xercesc::DOMElement* tag);
  bool readMultiplexOk (const xercesc::DOMElement* tag);
  std::vector<struct rspec_emulab_extension::policy>
    readPolicies (const xercesc::DOMElement* tag, int& count);
  std::string convertType (const std::string);
  std::string convertType (const std::string, const std::string);
};



#endif // #ifndef __RSPEC_PARSER_V2_H__

#endif // #ifdef WITH_XML


