/*
 * Copyright (c) 2005-2007 University of Utah and the Flux Group.
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

#ifdef WITH_XML

#ifndef __PARSE_ERROR_HANDLER_H
#define __PARSE_ERROR_HANDLER_H

#include <xercesc/util/PlatformUtils.hpp>

#include <xercesc/dom/DOM.hpp>
#include <xercesc/dom/DOMImplementation.hpp>
#include <xercesc/dom/DOMImplementationLS.hpp>
#include <xercesc/dom/DOMWriter.hpp>

#include <xercesc/framework/StdOutFormatTarget.hpp>
#include <xercesc/framework/LocalFileFormatTarget.hpp>
#include <xercesc/parsers/XercesDOMParser.hpp>
#include <xercesc/util/XMLUni.hpp>

#include <xercesc/util/XercesDefs.hpp>
#include <xercesc/sax/ErrorHandler.hpp>
#include <xercesc/sax/SAXParseException.hpp>

#include <xercesc/util/OutOfMemoryException.hpp>

#include <xercesc/sax2/XMLReaderFactory.hpp>
XERCES_CPP_NAMESPACE_USE

#include <iostream>
using namespace std;

#include "xmlhelpers.h"
#include "xstr.h"

class ParseErrorHandler : public ErrorHandler {
public:
    ParseErrorHandler() : hadError(false) { ; };
    ~ParseErrorHandler() { ; };
    
    /*
     * Implementation of the ErrorHandler functions
     */
    void warning(const SAXParseException& toCatch) { /* Ignore for now */ };
    void error(const SAXParseException& toCatch);
    void fatalError(const SAXParseException& toCatch);
    void resetErrors() { hadError = false; }
    
    bool sawError() const { return hadError; }
    
private:
	bool hadError;
    
};

#endif // for __PARSE_ERROR_HANDLER_H

#endif // for WITH_XML
