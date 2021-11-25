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
 * Implements the annotate methods which are independent of the type of file being annotated.
 */

static const char rcsid[] = "$Id: annotate.cc,v 1.2 2009-05-20 18:06:07 tarunp Exp $";

#ifdef WITH_XML

#include "annotate.h"
#include "common.h"
#include "xstr.h"
#include <string>

#include <xercesc/dom/DOM.hpp>
#include <xercesc/dom/DOMImplementation.hpp>
#include <xercesc/dom/DOMWriter.hpp>
#include <xercesc/framework/LocalFileFormatTarget.hpp>

XERCES_CPP_NAMESPACE_USE
using namespace std;

void annotate::write_annotated_file (const char* filename)
{
  // Get the current implementation
  DOMImplementation *impl = DOMImplementationRegistry::getDOMImplementation(NULL);
  if (!impl) { 
    cout << "*** Could not create DOMImplementationRegistry" << endl;
    exit(EXIT_FATAL);
  }

  // Construct the DOMWriter
  DOMWriter* writer = ((DOMImplementationLS*)impl)->createDOMWriter();
  if (!writer) {
    cout << "*** Could not create DOMWriter" << endl;
    exit(EXIT_FATAL);
  }
  
  // Make the output look pretty
  if (writer->canSetFeature(XMLUni::fgDOMWRTFormatPrettyPrint, true))
    writer->setFeature(XMLUni::fgDOMWRTFormatPrettyPrint, true);
  
  // Set the byte-order-mark feature      
  if (writer->canSetFeature(XMLUni::fgDOMWRTBOM, true))
    writer->setFeature(XMLUni::fgDOMWRTBOM, true);

  // Set the XML declaration feature
  if (writer->canSetFeature(XMLUni::fgDOMXMLDeclaration, true))
    writer->setFeature(XMLUni::fgDOMXMLDeclaration, true);

  // Construct the LocalFileFormatTarget
  XMLFormatTarget *outputFile = new xercesc::LocalFileFormatTarget(filename);
  if (!outputFile) {
    cout << "*** Could not create output file " << filename << endl;
    exit(EXIT_FATAL);
  }
  
  if (!(this->document)) {
    cout << "*** INTERNAL ERROR: this->document was NULL" << endl;
    exit(EXIT_FATAL);
  }

  // Serialize a DOMNode to the local file "<some-file-name>.xml"
  writer->writeNode(outputFile, *(this->virtual_root));
  
  // Flush the buffer to ensure all contents are written
  outputFile->flush();
  
  // Release the memory
  writer->release();
}

string annotate::printXML (const DOMElement* input)
{
  DOMElement* tag = (DOMElement*)(input);

  // Get the current implementation
  DOMImplementation *impl = DOMImplementationRegistry::getDOMImplementation(NULL);
  
  // Construct the DOMWriter
  DOMWriter* writer = ((DOMImplementationLS*)impl)->createDOMWriter();
  
  // Make the output look pretty
  if (writer->canSetFeature(XMLUni::fgDOMWRTFormatPrettyPrint, true))
    writer->setFeature(XMLUni::fgDOMWRTFormatPrettyPrint, true);
  
  // Set the byte-order-mark feature      
  if (writer->canSetFeature(XMLUni::fgDOMWRTBOM, true))
    writer->setFeature(XMLUni::fgDOMWRTBOM, true);

  // Serialize a DOMNode to the local file "<some-file-name>.xml"
  string rv = XStr(writer->writeToString(*dynamic_cast<DOMNode*>(tag))).c();
  
  // Release the memory
  writer->release();

  return rv;
}


#endif
