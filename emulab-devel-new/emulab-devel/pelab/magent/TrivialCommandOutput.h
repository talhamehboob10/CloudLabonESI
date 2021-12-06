/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
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

// TrivialCommandOutput.h

#ifndef TRIVIAL_COMMAND_OUTPUT_H_STUB_2
#define TRIVIAL_COMMAND_OUTPUT_H_STUB_2

#include "CommandOutput.h"

class TrivialCommandOutput : public CommandOutput
{
public:
  TrivialCommandOutput();
  virtual ~TrivialCommandOutput();
protected:
  virtual int startMessage(int size);
  virtual void endMessage(void);
  virtual void writeMessage(char const * message, int count);
private:
  void attemptWrite(void);
private:
  std::vector<char> partial;
  size_t start;
  size_t end;
};

#endif
