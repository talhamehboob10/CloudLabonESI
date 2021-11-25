/*
 * $Id: SGGPIO.h,v 1.2 2006-12-01 22:59:37 mike Exp $
 *
 ****************************************************************************
 *
 * uisp - The Micro In-System Programmer for Atmel AVR microcontrollers.
 *
 * Copyright (c) 2003 University of Utah and the Flux Group.
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
 *
 ****************************************************************************
 */

/*
  SGGPIO.h
  
  Direct Stargate/PXA GPIO Access
  
*/

#ifndef __SGGPIO_H
#define __SGGPIO_H

#include <stdlib.h>
#include <sys/types.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>

#define GPIO_bit(x)	(1 << ((x) & 0x1f))
#define GPIO_nr(x)      ((x) >> 5)

enum PXA_REG {
  PXA_GPLR = 0,
  PXA_GPDR = 1,
  PXA_GPSR = 2,
  PXA_GPCR = 3
};
#define NUM_REGS 4
#define NUM_REGNUMS 3

extern char *pxa_reg_names[];

#define PXA_REG_NAME(reg) pxa_reg_names[(reg)]

#define PROC_REG_PREFIX "/proc/cpu/registers"

class SGGPIO_PORT {

public:

  int setDir(int pin, unsigned int indir);
  int setPin(int pin, unsigned int inval);
  int readPin(int pin);
  unsigned int readGPIO(PXA_REG reg,  int regnum);
  int writeGPIO(PXA_REG reg, int regnum, unsigned int value);
  SGGPIO_PORT();
  ~SGGPIO_PORT();

private:

  int getGPIO(PXA_REG reg, int regnum);
  int GPIO_fds[NUM_REGS][NUM_REGNUMS];
};

#endif /* __SGGPIO_H */
