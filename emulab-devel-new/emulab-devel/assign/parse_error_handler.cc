/*
 * Copyright (c) 2007 University of Utah and the Flux Group.
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

static const char rcsid[] = "$Id: parse_error_handler.cc,v 1.2 2009-05-20 18:06:08 tarunp Exp $";

#ifdef WITH_XML

#include "parse_error_handler.h"

void ParseErrorHandler::error(const SAXParseException& toCatch) {
    cerr << "Error at file \"" << XStr(toCatch.getSystemId())
    << "\", line " << toCatch.getLineNumber()
    << ", column " << toCatch.getColumnNumber()
    << "\n   Message: " << XStr(toCatch.getMessage()) << endl;
    this->hadError = true;
}

void ParseErrorHandler::fatalError(const SAXParseException& toCatch) {
    XERCES_STD_QUALIFIER cerr << "Fatal Error at file \"" << XStr(toCatch.getSystemId())
    << "\", line " << toCatch.getLineNumber()
    << ", column " << toCatch.getColumnNumber()
    << "\n   Message: " << XStr(toCatch.getMessage()) << XERCES_STD_QUALIFIER endl;
    this->hadError = true;
}

#endif 
