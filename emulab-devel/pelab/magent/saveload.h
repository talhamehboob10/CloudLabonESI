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

// saveload.h

#ifndef SAVE_LOAD_H_STUB_2
#define SAVE_LOAD_H_STUB_2

class Command;

class Header
{
public:
  Header() : type(0), size(0), version(global::CONTROL_VERSION) {}

  unsigned char type;
  unsigned short size;
  // The following field is co-located with the version 0 'transport'
  // field. Since version 0 only used TCP_CONNECTION (== 0), it can be
  // identified by that field.
  unsigned char version;
  ElabOrder key;

  enum { PREFIX_SIZE = sizeof(unsigned char)*2 + sizeof(unsigned short) };

  enum { VERSION_0_SIZE = sizeof(unsigned short)*2
         + sizeof(unsigned int) };

  enum { VERSION_1_SIZE = ElabOrder::idSize };

  // headerSize() yields the header size for the current version.
  static int headerSize(void)
  {
    switch (global::CONTROL_VERSION)
    {
    case 0:
      return PREFIX_SIZE + VERSION_0_SIZE;
    case 1:
      return PREFIX_SIZE + VERSION_1_SIZE;
    default:
      return PREFIX_SIZE + VERSION_1_SIZE;
    }
  }

  // maxHeaderSize is the buffer for the size of the largest version.
  enum { maxHeaderSize = PREFIX_SIZE + VERSION_1_SIZE };
};

int getLastSaveloadSize(void);

// These take in a current position in the buffer and return the
// position after the saved or loaded item.

// If buffer is NULL, then nothing is actually written, but the write
// size is still updated. Use this to determine the size of the buffer
// to write.
char * saveChar(char * buffer, unsigned char value);
char * saveShort(char * buffer, unsigned short value);
char * saveInt(char * buffer, unsigned int value);
char * saveBuffer(char * buffer, void const * input, unsigned int size);
char * saveHeader(char * buffer, Header const & value);
char * saveOptions(char * buffer, std::list<Option> const & options);
char * savePacket(char * buffer, PacketInfo const & value);

// If buffer is NULL, that is an error.
char * loadChar(char * buffer, unsigned char * value);
char * loadShort(char * buffer, unsigned short * value);
char * loadInt(char * buffer, unsigned int * value);
char * loadBuffer(char * buffer, void * output, unsigned int size);
char * loadHeader(char * buffer, Header * value);
char * loadOptions(char * buffer, std::list<Option> * options);
std::auto_ptr<Command> loadCommand(Header * head, char * body);
// It is presumed that value contains pointers to the various
// substructures that need to be filled.
char * loadPacket(char * buffer, PacketInfo * value, struct tcp_info & kernel,
                  struct ip & ip, struct tcphdr & tcp, struct udphdr & udp,
                  std::list<Option> & ipOptions,
                  std::list<Option> & tcpOptions,
                  std::vector<unsigned char> & payload,
                  unsigned char version);

#endif
