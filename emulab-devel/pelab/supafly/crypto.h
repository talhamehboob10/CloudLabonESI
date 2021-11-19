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

#ifndef __CRYPTO_H__
#define __CRYPTO_H__

#include <openssl/rand.h>
#include <openssl/des.h>

DES_cblock *sgenkey();
DES_cblock *sgeniv();
/* note: if IV is null, don't do cbc; otherwise, do it. */
int sencrypt(unsigned char *input,unsigned char *output,
	     unsigned int len,DES_cblock *k1,DES_cblock *k2,
	     DES_cblock *iv);
int sdecrypt(unsigned char *input,unsigned char *output,
	     unsigned int len,DES_cblock *k1,DES_cblock *k2,
	     DES_cblock *iv);


#endif /* __CRYPTO_H__ */
