/*
 * Copyright (c) 2000-2010 University of Utah and the Flux Group.
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
#include <sys/socket.h>
#include <openssl/x509.h>

/*
 * SSL prototypes and definitions.
 */

int		tmcd_server_sslinit(void);
int		tmcd_client_sslinit(void);
int		tmcd_sslaccept(int sock, struct sockaddr *, socklen_t *, int);
int		tmcd_sslconnect(int sock, const struct sockaddr *, socklen_t);
int		tmcd_sslwrite(int sock, const void *buf, size_t nbytes);
int		tmcd_sslread(int sock, void *buf, size_t nbytes);
int		tmcd_sslclose(int sock);
int		tmcd_sslverify_client(char *, char *, char *, int);
int		tmcd_quote_hash(void *, size_t, void *);
int		tmcd_quote_verifysig(void *, void *, size_t, void *);
X509*		tmcd_sslgetpeercert(void);
X509*		tmcd_sslrowtocert(char*, char*);
int		isssl;
int		nousessl;
int		usetpm;

/*
 * The client sends this tag to indicate that it is SSL capable.
 * Only local nodes can skip SSL. Remote nodes must use SSL!
 */
#define SPEAKSSL	"ISPEAKSSL_TMCDV10"

/*
 * When compiled to use SSL, redefine the routines appropriately
 */
#ifdef WITHSSL
#define ACCEPT		tmcd_sslaccept
#define CONNECT		tmcd_sslconnect
#define WRITE		tmcd_sslwrite
#define READ		tmcd_sslread
#define CLOSE		tmcd_sslclose
#else
#define ACCEPT		tmcd_accept
#define CONNECT		connect
#define WRITE		write
#define READ		read
#define CLOSE		close
#endif /*WITHSSL*/
