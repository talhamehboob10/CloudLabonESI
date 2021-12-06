/*
 * Copyright (c) 2010-2017 University of Utah and the Flux Group.
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
 * Upload functions used by both the upload client and server.
 *
 * TODO: should be able to specify connection and IO timeouts.
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/time.h>
#include "decls.h"
#include "utils.h"
#include "uploadio.h"

static int SOCK_Read(int sockfd, void *buf, int num, conn *conn);
static int SOCK_Write(int sockfd, const void *buf, int num, conn *conn);
#ifdef USE_SSL
static int SSL_Read(SSL *ssl, void *buf, int num);
static int SSL_Write(SSL *ssl, const void *buf, int num);
#endif

/*
 * Accept a connection from the indicated client on the given socket.
 * Return a conn object for the new socket.
 */
conn *
conn_accept_tcp(int sock, struct in_addr *client, int conntimo, int iotimo)
{
	conn *newconn;
	int nsock, sz;
	struct sockaddr_in sin;
	socklen_t len;

	newconn = malloc(sizeof *newconn);
	if (newconn == NULL) {
		FrisLog("Out of memory");
		return NULL;
	}

 again:
	if (conntimo) {
		struct timeval tv;
		fd_set fds;

		FD_ZERO(&fds);
		FD_SET(sock, &fds);
		tv.tv_sec = conntimo;
		tv.tv_usec = 0;
		if (select(sock+1, &fds, NULL, NULL, &tv) != 1) {
			FrisLog("Accept timeout");
			free(newconn);
			return NULL;
		}
	}

	len = sizeof(sin);
	nsock = accept(sock, (struct sockaddr *)&sin, &len);
	if (nsock < 0) {
		FrisPwarning("accept");
		free(newconn);
		return NULL;
	}
	if (client->s_addr != INADDR_ANY) {
		if (sin.sin_addr.s_addr != client->s_addr) {
			FrisError("Reject connection from %s",
				  inet_ntoa(sin.sin_addr));
			close(nsock);
			goto again;
		}
	} else
		client->s_addr = sin.sin_addr.s_addr;

	if (iotimo > 0) {
		struct timeval tv;

		tv.tv_sec = iotimo;
		tv.tv_usec = 0;
		if (setsockopt(nsock, SOL_SOCKET, SO_RCVTIMEO,
			       &tv, sizeof tv) ||
		    setsockopt(nsock, SOL_SOCKET, SO_SNDTIMEO,
			       &tv, sizeof tv)) {
			FrisPwarning("%s: accept setsockopt",
				     inet_ntoa(sin.sin_addr));
			close(nsock);
			free(newconn);
			return NULL;
		}
	}

	sz = sockbufsize;
	if (setsockopt(nsock, SOL_SOCKET, SO_RCVBUF, &sz, sizeof(sz)) < 0)
		FrisPwarning("Could not set send socket buffer size to %d", sz);

	newconn->ctype = CONN_SOCKET;
	newconn->flags = 0;
	newconn->desc.sockfd = nsock;

	return newconn;
}

conn *
conn_open(in_addr_t addr, in_port_t port, int usessl, int conntimo, int iotimo)
{
	conn *newconn = malloc(sizeof *newconn);
	int sz;

	if (newconn == NULL) {
		FrisLog("Out of memory");
		return NULL;
	}

	if (!usessl) {
		struct sockaddr_in servaddr;
		int sock, flags = 0;
	
		servaddr.sin_family = AF_INET;
		servaddr.sin_addr.s_addr = htonl(addr);
		servaddr.sin_port = htons(port);

		sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
		if (sock < 0) {
			FrisPwarning("%s:%d socket",
				     inet_ntoa(servaddr.sin_addr), port);
			free(newconn);
			return NULL;
		}
		if (conntimo > 0) {
			flags = fcntl(sock, F_GETFL, 0);
			if (fcntl(sock, F_SETFL, flags|O_NONBLOCK)) {
				FrisPwarning("%s:%d connect fcntl",
					     inet_ntoa(servaddr.sin_addr),
					     port);
				close(sock);
				free(newconn);
				return NULL;
			}
		}
		if (connect(sock, (struct sockaddr *)&servaddr,
			    sizeof(servaddr)) < 0) {
			struct timeval tv;
			fd_set rfds, wfds;
			int err = errno;
			socklen_t len;

			if (conntimo == 0 || err != EINPROGRESS) {
				FrisPwarning("%s:%d connect",
					     inet_ntoa(servaddr.sin_addr),
					     port);
				close(sock);
				free(newconn);
				return NULL;
			}

			FD_ZERO(&rfds);
			FD_SET(sock, &rfds);
			wfds = rfds;
			tv.tv_sec = conntimo;
			tv.tv_usec = 0;
			if (select(sock+1, &rfds, &wfds, NULL, &tv) < 1) {
				FrisLog("%s:%d connect timeout",
					inet_ntoa(servaddr.sin_addr), port);

				close(sock);
				free(newconn);
				return NULL;
			}
			err = 0;
			len = sizeof err;
			if (getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &len) ||
			    err != 0) {
				errno = err;
				FrisPwarning("%s:%d connect getsockopt",
					     inet_ntoa(servaddr.sin_addr),
					     port);
				close(sock);
				free(newconn);
				return NULL;
			}

		}
		if (conntimo > 0 && fcntl(sock, F_SETFL, flags)) {
			FrisPwarning("%s:%d connect fcntl",
				     inet_ntoa(servaddr.sin_addr),
				     port);
			close(sock);
			free(newconn);
			return NULL;
		}

		if (iotimo > 0) {
			struct timeval tv;

			tv.tv_sec = iotimo;
			tv.tv_usec = 0;
			if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO,
				       &tv, sizeof tv) ||
			    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO,
				       &tv, sizeof tv)) {
				FrisPwarning("%s:%d connect setsockopt",
					     inet_ntoa(servaddr.sin_addr),
					     port);
				close(sock);
				free(newconn);
				return NULL;
			}
		}

		sz = sockbufsize;
		if (setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &sz, sizeof(sz)) < 0)
			FrisPwarning("Could not set send socket buffer size to %d", sz);

		newconn->ctype = CONN_SOCKET;
		newconn->flags = 0;
		newconn->desc.sockfd = sock;
	}
#ifdef USE_SSL
	else {
		BIO *bio;
		struct in_addr in;
		char bioname[64];
		long err;

		if (conntimo > 0 || iotimo > 0) {
			FrisLog("Timeouts not implemented with SSL connections.");
			return NULL;
		}
		in.s_addr = htonl(addr);
		snprintf(bioname, sizeof bioname, "%s:%d",
			 inet_ntoa(in), htons(port));

		init_OpenSSL();
		seed_prng(1024);
		ctx = setup_client_ctx();

		bio = BIO_new_connect(bioname);
		if (!bio) {
			FrisLog("Error creating connection BIO");
			SSL_CTX_free(ctx);
			free(newconn);
			return NULL;
		}
		if (BIO_do_connect(bio) <= 0) {
			FrisLog("Error connecting to remote machine.");
			BIO_free(bio);
			SSL_CTX_free(ctx);
			free(newconn);
			return NULL;
		}

		ssl = SSL_new(ctx);
		SSL_set_bio(ssl, bio, bio);
		if (SSL_connect(ssl) <= 0) {
			FrisLog("Error connecting SSL object.");
			SSL_free(ssl);
			BIO_free(bio);
			SSL_CTX_free(ctx);
			free(newconn);
			return NULL;
		}

		/* XXX do this before check so we can use conn_close */
		newconn->ctype = CONN_SSL;
		newconn->flags = 0;
		newconn->desc.sslstate.ssl = ssl;
		newconn->desc.sslstate.ctx = ctx;

		err = post_connection_check(ssl, inet_ntoa(in));
		if (err != X509_V_OK) {
			FrisLog("Error: peer certificate: %s",
				X509_verify_cert_error_string(err));
			FrisLog("Error checking SSL object after connection.");
			conn_close(newconn);
			return NULL;
		}

	}
#endif

	return newconn;
}

int
conn_close(conn *conn)
{
	int rv = -1;

	if (conn != NULL) {
		if (conn->ctype == CONN_SOCKET) {
			rv = close(conn->desc.sockfd);
		}
#ifdef USE_SSL
		else if (conn->ctype == CONN_SSL) {
			SSL *ssl = conn->desc.ssl;

			if (SSL_get_shutdown(ssl) & SSL_RECEIVED_SHUTDOWN) {
				SSL_shutdown(ssl);
			} else {
				SSL_clear(ssl);
			}
			SSL_free(ssl);
			SSL_CTX_free(ctx);
			ERR_remove_state(0);
			rv = 0;
		}
#endif
		free(conn);
	}

	return rv;
}

int
conn_read(conn *conn, void *buf, int num)
{
	if (conn->flags & CONN_ATEOF)
		return 0;
	if (conn->flags & CONN_TIMEDOUT) {
		errno = ETIMEDOUT;
		return -1;
	}

	if (conn->ctype == CONN_SOCKET)
		return SOCK_Read(conn->desc.sockfd, buf, num, conn);
#ifdef USE_SSL
	if (conn->ctype == CONN_SSL)
		return SSL_Read(conn->desc.ssl, buf, num);
#endif

	errno = EINVAL;
	return -1;
}

int
conn_write(conn *conn, const void *buf, int num)
{
	if (conn->flags & CONN_ATEOF)
		return 0;
	if (conn->flags & CONN_TIMEDOUT) {
		errno = ETIMEDOUT;
		return -1;
	}

	if (conn->ctype == CONN_SOCKET)
		return SOCK_Write(conn->desc.sockfd, buf, num, conn);
#ifdef USE_SSL
	if (conn->ctype == CONN_SSL)
		return SSL_Write(conn->desc.ssl, buf, num);
#endif

	errno = EINVAL;
	return -1;
}

static int
SOCK_Read(int sockfd, void *buf, int num, conn *conn)
{
	int  nleft;
	int  nread;
	int  nio;
	char *ptr;
	
	ptr = (char *)buf;
	nleft = num;
	while (nleft > 0) {
		if (MAX_TCP_BYTES && nleft > MAX_TCP_BYTES)
			nio = MAX_TCP_BYTES;
		else
			nio = nleft;
		if ((nread = read(sockfd, ptr, nio)) < 0) {
			if (errno == EINTR)
				nread = 0; /* and call read() again */
			else if (errno == EWOULDBLOCK || errno == ETIMEDOUT) {
				conn->flags |= CONN_TIMEDOUT;
				break;
			} else
				return -1;
		} else if (nread == 0) {
			conn->flags |= CONN_ATEOF;
			break; /* EOF */
		}
		nleft -= nread;
		ptr += nread;
	}
	return (num - nleft); /* return >= 0 */
}

static int
SOCK_Write(int sockfd, const void *buf, int num, conn *conn)
{
	int  nleft;
	int  nwritten;
	int  nio;
	const char *ptr;
	
	ptr = (const char *)buf;
	nleft = num;
	while (nleft > 0) {
		if (MAX_TCP_BYTES && nleft > MAX_TCP_BYTES)
			nio = MAX_TCP_BYTES;
		else
			nio = nleft;
		if ((nwritten = write(sockfd, ptr, nio)) < 0) {
			if (errno == EINTR)
				nwritten = 0; /* and call write() again */
			else if (errno == EWOULDBLOCK) {
				conn->flags |= CONN_TIMEDOUT;
				break;
			} else
				return -1; /* error */
		} else if (nwritten == 0) {
			conn->flags |= CONN_ATEOF;
			break;
		}
		nleft -= nwritten;
		ptr += nwritten;
	}
	return (num - nleft);
}

#ifdef USE_SSL
void
init_OpenSSL(void)
{
	if (!SSL_library_init())
		FrisFatal("Error: OpenSSL initialization failed.");
	SSL_load_error_strings();
}

int
seed_prng(int bytes)
{
	if (!RAND_load_file("/dev/urandom", bytes))
		return 0;
	return 1;
}

int
pem_passwd_cb(char *buf, int size, int flag, void *userdata)
{
	int ret;

	FrisLog("PEM password callback called.");
	ret = snprintf(buf, size, PASSWORD);
	if (ret < 0)
		FrisLog("Error: Could not set password in callback.");
	else if (ret >= size)
		FrisLog("Warning: Password was trucated in callback.");

	return strlen(PASSWORD);
}

int
verify_callback(int ok, X509_STORE_CTX * store)
{
	char data[MAXLINE];

	if (!ok) {
		X509 *cert = X509_STORE_CTX_get_current_cert(store);
		int depth = X509_STORE_CTX_get_error_depth(store);
		int err = X509_STORE_CTX_get_error(store);

		FrisLog("Error: Certificate at depth: %d", depth);
		X509_NAME_oneline(X509_get_issuer_name(cert), data, MAXLINE);
		FrisLog("Error:    issuer   = %s", data);
		X509_NAME_oneline(X509_get_subject_name(cert), data, MAXLINE);
		FrisLog("Error:    subject  = %s", data);
		FrisLog("Error:    err %d:%s\n",
			err, X509_verify_cert_error_string(err));
	}

	return ok;
}

SSL_CTX *
setup_client_ctx(void)
{
	SSL_CTX *ctx;

	ctx = SSL_CTX_new(SSLv23_method());
	SSL_CTX_set_default_passwd_cb(ctx, pem_passwd_cb);
	SSL_CTX_set_mode(ctx, SSL_MODE_AUTO_RETRY);
	if (SSL_CTX_load_verify_locations(ctx, CLIENT_CAFILE, NULL) != 1)
		FrisFatal("Error loading CA file and/or directory.");
	if (SSL_CTX_set_default_verify_paths(ctx) != 1)
		FrisFatal("Error loading default CA file and/or directory.\n");
	if (SSL_CTX_use_certificate_chain_file(ctx, CLIENT_CERTFILE) != 1)
		FrisFatal("Error loading client certificate from file.");
	if (SSL_CTX_use_PrivateKey_file(ctx, CLIENT_CERTFILE,
					SSL_FILETYPE_PEM) != 1)
		FrisFatal("Error loading private key from file.");
	SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, verify_callback);
	SSL_CTX_set_verify_depth(ctx, 4);

	return ctx;
}

long
post_connection_check(SSL *ssl, char *host)
{
	/* TODO */
	return X509_V_OK;
}

/* Designed for blocking IO with auto retry set */
int
SSL_Read(SSL *ssl, void *buf, int num)
{
	int nread, err;

	nread = SSL_read(ssl, buf, num);
	if (nread <= 0) {
		err = SSL_get_error(ssl, nread);
		if (err == SSL_ERROR_ZERO_RETURN) {
			FrisLog("Error: SSL_read: Connection was closed.");
		} else {
			FrisLog("Error: SSL_read failed with err=%d.", err);
		}
	}
	/* Cleanup state? */
	if (nread != num) {
		FrisLog("Warning: SSL_read wanted %d bytes but got %d.",
			num, nread);
	}

	return nread;
}

/* Designed for blocking IO with auto retry set */
int
SSL_Write(SSL * ssl, const void *buf, int num)
{
	int nwrote, err;

	nwrote = SSL_write(ssl, buf, num);
	if (nwrote <= 0) {
		err = SSL_get_error(ssl, nwrote);
		if (err == SSL_ERROR_ZERO_RETURN) {
			FrisLog("Error: SSL_write: Connection was closed.");
		} else {
			FrisLog("Error: SSL_write failed with err=%d.", err);
		}
	}
	/* Clean up state? */
	if (nwrote != num) {
		FrisLog("Warning: SSL_write tried %d bytes but sent %d.",
			num, nwrote);
	}

	return nwrote;
}
#endif
