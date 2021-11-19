/*
 * Copyright (c) 2004, 2005 University of Utah and the Flux Group.
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

/**
 * @file mtp.c
 */

#include <math.h>
#include <errno.h>
#include <stdio.h>
#include <stdarg.h>
#include <fcntl.h>
#include <inttypes.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "mtp.h"

/**
 * Human readable names for the MTP roles.
 */
static char *mtp_role_strings[MTP_ROLE_MAX] = {
    "NONE",
    "vmc",
    "emc",
    "rmc",
    "emulab",
    "robot"
};

/**
 * Human readable names for the MTP statuses.
 */
static char *mtp_status_strings[] = {
    "unknown",
    "NONE",
    "idle",
    "moving",
    "error",
    "complete",
    "contact",
    "aborted",
};

static int mtp_read(char *handle, char *data, int len)
{
    mtp_handle_t mh = (mtp_handle_t)handle;
    int retval;

    assert(handle != NULL);
    assert(data != NULL);

    do {
	retval = read(mh->mh_fd, data, len);
    } while ((retval == -1) && (errno == EINTR));

    if (retval == 0) {
	mh->mh_flags |= MHF_EOF;
	retval = -1;
    }
    else if (retval > 0) {
	mh->mh_remaining += retval;
    }
    else {
	printf(" mtp_read %d %s\n", retval, strerror(errno));
    }
    
    // printf("%d read(%p(%d), %p, %d)\n", retval, mh, mh->mh_fd, data, len);

    return retval;
}

static int mtp_write(char *handle, char *data, int len)
{
    mtp_handle_t mh = (mtp_handle_t)handle;
    int retval;

    assert(handle != NULL);
    assert(data != NULL);
    
    retval = write(mh->mh_fd, data, len);

    // printf("%d write(%p(%d), %p, %d)\n", retval, mh, mh->mh_fd, data, len);

    return retval;
}

int mtp_packet_invariant(mtp_packet_t *packet)
{
    assert(packet != NULL);
    assert(packet->vers == MTP_VERSION);
    assert(packet->role > 0);
    assert(packet->role < MTP_ROLE_MAX);
    assert(packet->data.opcode > 0);
    assert(packet->data.opcode < MTP_OPCODE_MAX);
    
    return 1;
}

mtp_handle_t mtp_create_handle(int fd)
{
    mtp_handle_t mh, retval = NULL;

    assert(fd >= 0);

    if ((mh = calloc(1, sizeof(struct mtp_handle))) == NULL) {
	errno = ENOMEM;
    }
    else {
	mh->mh_fd = fd;
	xdrrec_create(&mh->mh_xdr, 0, 0, (char *)mh, mtp_read, mtp_write);

	retval = mh;
	mh = NULL;
    }
    
    return retval;
}

int mtp_gethostbyname(struct sockaddr_in *host_addr, char *host, int port)
{
    struct hostent *host_ent;
    int retval = 0;
    
    assert(host_addr != NULL);
    assert(host != NULL);
    assert(strlen(host) > 0);
    
    memset(host_addr, 0, sizeof(struct sockaddr_in));
#ifndef linux
    host_addr->sin_len = sizeof(struct sockaddr_in);
#endif
    host_addr->sin_family = AF_INET;
    host_addr->sin_port = htons(port);
    if( (host_ent = gethostbyname(host)) != NULL ) {
	memcpy((char *)&host_addr->sin_addr.s_addr,
	       host_ent->h_addr,
	       host_ent->h_length);
	retval = 1;
    }
    else {
	retval = inet_aton(host, &host_addr->sin_addr);
    }
    return( retval );
}

int mtp_initunixpath(struct sockaddr_un *host_addr, char *path)
{
    int retval = 0;
    
    assert(host_addr != NULL);
    assert(path != NULL);
    assert(strlen(path) > 0);

    memset(host_addr, 0, sizeof(struct sockaddr_un));
#ifndef linux
    host_addr->sun_len = sizeof(struct sockaddr_un);
#endif
    host_addr->sun_family = AF_UNIX;
    if (strlen(path) < sizeof(host_addr->sun_path)) {
	strcpy(host_addr->sun_path, path);
	retval = 1;
    }
    
    return( retval );
}

mtp_handle_t mtp_create_handle3(char *host, int port, char *path, int nonblock)
{
    mtp_handle_t retval = NULL;
    int family, fd;

    union {
	struct sockaddr s;
	struct sockaddr_in sin;
	struct sockaddr_un sun;
    } saddr;

    family = (host != NULL) ? AF_INET : AF_UNIX;
    if ((fd = socket(family, SOCK_STREAM, 0)) == -1) {
	perror("socket");
    }
    else if (((family == AF_INET) &&
	      !mtp_gethostbyname(&saddr.sin, host, port)) ||
	     ((family == AF_UNIX) && !mtp_initunixpath(&saddr.sun, path))) {
    }
    else if (nonblock && (fcntl(fd, F_SETFL, O_NONBLOCK) < 0)) {
	perror("fcntl");
    }
    else if ((connect(fd,
		      &saddr.s,
		      (family == AF_INET) ?
		      sizeof(saddr.sin) : sizeof(saddr.sun)) == -1) &&
	     (errno != EINPROGRESS)) {
	perror("connect");
    }
    else if ((retval = mtp_create_handle(fd)) == NULL) {
	perror("mtp_create_handle");
    }
    else {
	fd = -1;
    }

    if (fd != -1)
	close(fd);
    
    return retval;
}

mtp_handle_t mtp_create_handle2(char *host, int port, char *path)
{
    return mtp_create_handle3(host, port, path, 0);
}

int mtp_bind(char *host, int port, char *path)
{
    int family, fd, retval = -1;

    union {
	struct sockaddr s;
	struct sockaddr_in sin;
	struct sockaddr_un sun;
    } saddr;

    family = (path != NULL) ? AF_UNIX : AF_INET;
    if ((fd = socket(family, SOCK_STREAM, 0)) == -1) {
	perror("socket");
    }
    else if (((family == AF_INET) &&
	      !mtp_gethostbyname(&saddr.sin, host, port)) ||
	     ((family == AF_UNIX) && !mtp_initunixpath(&saddr.sun, path))) {
    }
    else {
	int on_off = 1;

	if (family == AF_INET)
	    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on_off, sizeof(int));
	else
	    unlink(path);
	if (bind(fd,
		 &saddr.s,
		 (family == AF_INET) ?
		 sizeof(saddr.sin) : sizeof(saddr.sun)) == -1) {
	    perror("bind");
	}
	else if ((family == AF_UNIX) && (chmod(path, S_IRWXU) == -1)) {
	    perror("fchmod");
	}
	else if (listen(fd, 5) == -1) {
	    perror("listen");
	}
	else {
	    retval = fd;
	    fd = -1;
	}
    }

    if (fd != -1)
	close(fd);
    
    return retval;
}

void mtp_delete_handle(mtp_handle_t mh)
{
    if (mh != NULL) {
	mh->mh_fd = -1;
	xdr_destroy(&mh->mh_xdr);
	
	free(mh);
	mh = NULL;
    }
}

mtp_error_t mtp_receive_packet(mtp_handle_t mh, struct mtp_packet *packet)
{
    mtp_error_t retval;

    assert(mh != NULL);
    assert(packet != NULL);

    memset(packet, 0, sizeof(struct mtp_packet));
    
    mh->mh_xdr.x_op = XDR_DECODE;
    /* Must always skip before reading the next record. */
    xdrrec_skiprecord(&mh->mh_xdr);
    if (xdr_mtp_packet(&mh->mh_xdr, packet)) {
	/* Subtract the packet size and the xdrrec length header. */
	mh->mh_remaining -= xdr_sizeof(xdr_mtp_packet, packet) + 4;
	
	retval = MTP_PP_SUCCESS;
    }
    else if (mh->mh_flags & MHF_EOF) {
	fprintf(stderr, "mtp: EOF for %d\n", mh->mh_fd);
	mh->mh_remaining = 0;
	retval = MTP_PP_ERROR_EOF;
    }
    else {
	retval = MTP_PP_ERROR_READ;
    }

    return retval;
}

mtp_error_t mtp_send_packet(mtp_handle_t mh, struct mtp_packet *packet)
{
    mtp_error_t retval;

    assert(mh != NULL);
    assert(packet != NULL);
    assert(mtp_packet_invariant(packet));

    mh->mh_xdr.x_op = XDR_ENCODE;
    if (!xdr_mtp_packet(&mh->mh_xdr, packet)) {
	perror("xdr_mtp_packet");
	retval = MTP_PP_ERROR_WRITE;
    }
    else if (!xdrrec_endofrecord(&mh->mh_xdr, 1)) {
	perror("xdrrec_endofrecord");
	retval = MTP_PP_ERROR_WRITE;
    }
    else {
	retval = MTP_PP_SUCCESS;
    }
    
    return retval;
}

mtp_error_t mtp_init_packetv(struct mtp_packet *mp,
			     mtp_tag_t tag,
			     va_list args)
{
    mtp_error_t retval = MTP_PP_SUCCESS;

    assert(mp != NULL);

    memset(mp, 0, sizeof(struct mtp_packet));
    mp->vers = MTP_VERSION;
    
    while (tag != MA_TAG_DONE) {
	struct contact_point *cp;
	int lpc;
	
	assert(tag >= MA_TAG_DONE);
	if (tag >= MA_TAG_MAX) {
	    printf("Tag: %x\n", tag);
	}
 
	assert(tag < MA_TAG_MAX);
	
	switch (tag) {
	case MA_TAG_DONE:
	case MA_TAG_MAX:
	    assert(0);
	    break;
	case MA_Opcode:
	    mp->data.opcode = va_arg(args, mtp_opcode_t);
	    break;
	case MA_Role:
	    mp->role = va_arg(args, mtp_role_t);
	    break;
	case MA_ID:
	    mp->data.mtp_payload_u.error.id = va_arg(args, int);
	    break;
	case MA_Code:
	    mp->data.mtp_payload_u.error.code = va_arg(args, int);
	    break;
	case MA_Message:
	    mp->data.mtp_payload_u.error.msg = va_arg(args, char *);
	    break;
#if 0
	case MA_Horizontal:
	    mp->data.mtp_payload_u.config_rmc.box.horizontal =
		va_arg(args, double);
	    break;
	case MA_Vertical:
	    mp->data.mtp_payload_u.config_rmc.box.vertical =
		va_arg(args, double);
	    break;
#endif
	case MA_RobotLen:
	    mp->data.mtp_payload_u.config_rmc.robots.robots_len =
		va_arg(args, int);
	    break;
	case MA_RobotVal:
	    mp->data.mtp_payload_u.config_rmc.robots.robots_val =
		va_arg(args, struct robot_config *);
	    break;
	case MA_CameraLen:
	    mp->data.mtp_payload_u.config_vmc.cameras.cameras_len =
		va_arg(args, int);
	    break;
	case MA_CameraVal:
	    mp->data.mtp_payload_u.config_vmc.cameras.cameras_val =
		va_arg(args, struct camera_config *);
	    break;
	case MA_BoundsVal:
	    mp->data.mtp_payload_u.config_rmc.bounds.bounds_val = 
		va_arg(args, struct box *);
	    break;
	case MA_BoundsLen:
	    mp->data.mtp_payload_u.config_rmc.bounds.bounds_len = 
		va_arg(args, int);
	    break;
	case MA_ObstacleLen:
	    mp->data.mtp_payload_u.config_rmc.obstacles.obstacles_len =
		va_arg(args, int);
	    break;
	case MA_ObstacleVal:
	    switch (mp->data.opcode) {
	    case MTP_CONFIG_RMC:
		mp->data.mtp_payload_u.config_rmc.obstacles.obstacles_val =
		    va_arg(args, struct obstacle_config *);
		break;
	    case MTP_CREATE_OBSTACLE:
		mp->data.mtp_payload_u.create_obstacle.config =
		    *(va_arg(args, struct obstacle_config *));
		break;
	    case MTP_UPDATE_OBSTACLE:
		mp->data.mtp_payload_u.update_obstacle =
		    *(va_arg(args, struct obstacle_config *));
		break;
	    case MTP_REMOVE_OBSTACLE:
		mp->data.mtp_payload_u.remove_obstacle =
		    (va_arg(args, struct obstacle_config *))->id;
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_RobotID:
	    switch (mp->data.opcode) {
	    case MTP_REQUEST_POSITION:
		mp->data.mtp_payload_u.request_position.robot_id =
		    va_arg(args, int);
		break;
	    case MTP_UPDATE_POSITION:
		mp->data.mtp_payload_u.update_position.robot_id =
		    va_arg(args, int);
		break;
	    case MTP_UPDATE_ID:
		mp->data.mtp_payload_u.update_id.robot_id =
		    va_arg(args, int);
		break;
	    case MTP_COMMAND_GOTO:
		mp->data.mtp_payload_u.command_goto.robot_id =
		    va_arg(args, int);
		break;
	    case MTP_COMMAND_STOP:
		mp->data.mtp_payload_u.command_stop.robot_id =
		    va_arg(args, int);
		break;
	    case MTP_COMMAND_WHEELS: /* DAN */
		mp->data.mtp_payload_u.command_wheels.robot_id =
		    va_arg(args, int);
		break;
	    case MTP_COMMAND_STARTNULL: /* DAN */
		mp->data.mtp_payload_u.command_startnull.robot_id =
		    va_arg(args, int);
		break;
	    case MTP_WIGGLE_REQUEST:
		mp->data.mtp_payload_u.wiggle_request.robot_id = 
		    va_arg(args, int);
		break;
	    case MTP_WIGGLE_STATUS:
		mp->data.mtp_payload_u.wiggle_status.robot_id = 
		    va_arg(args, int);
		break;
	    case MTP_REQUEST_REPORT:
		mp->data.mtp_payload_u.request_report.robot_id = 
		    va_arg(args, int);
		break;
	    case MTP_CREATE_OBSTACLE:
		mp->data.mtp_payload_u.create_obstacle.robot_id =
		    va_arg(args, int);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_Position:
	    switch (mp->data.opcode) {
	    case MTP_UPDATE_POSITION:
		mp->data.mtp_payload_u.update_position.position =
		    *(va_arg(args, struct robot_position *));
		break;
	    case MTP_REQUEST_ID:
		mp->data.mtp_payload_u.request_id.position =
		    *(va_arg(args, struct robot_position *));
		break;
	    case MTP_COMMAND_GOTO:
		mp->data.mtp_payload_u.command_goto.position =
		    *(va_arg(args, struct robot_position *));
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_X:
	    switch (mp->data.opcode) {
	    case MTP_UPDATE_POSITION:
		mp->data.mtp_payload_u.update_position.position.x =
		    va_arg(args, double);
		break;
	    case MTP_REQUEST_ID:
		mp->data.mtp_payload_u.request_id.position.x =
		    va_arg(args, double);
		break;
	    case MTP_COMMAND_GOTO:
		mp->data.mtp_payload_u.command_goto.position.x =
		    va_arg(args, double);
		break;
	    case MTP_CONFIG_VMC_CLIENT:
		mp->data.mtp_payload_u.config_vmc_client.fixed_x =
		    va_arg(args, double);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_Y:
	    switch (mp->data.opcode) {
	    case MTP_UPDATE_POSITION:
		mp->data.mtp_payload_u.update_position.position.y =
		    va_arg(args, double);
		break;
	    case MTP_REQUEST_ID:
		mp->data.mtp_payload_u.request_id.position.y =
		    va_arg(args, double);
		break;
	    case MTP_COMMAND_GOTO:
		mp->data.mtp_payload_u.command_goto.position.y =
		    va_arg(args, double);
		break;
	    case MTP_CONFIG_VMC_CLIENT:
		mp->data.mtp_payload_u.config_vmc_client.fixed_y =
		    va_arg(args, double);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_Theta:
	    switch (mp->data.opcode) {
	    case MTP_UPDATE_POSITION:
		mp->data.mtp_payload_u.update_position.position.theta =
		    va_arg(args, double);
		break;
	    case MTP_REQUEST_ID:
		mp->data.mtp_payload_u.request_id.position.theta =
		    va_arg(args, double);
		break;
	    case MTP_COMMAND_GOTO:
		mp->data.mtp_payload_u.command_goto.position.theta =
		    va_arg(args, double);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_vleft: /* DAN */
	    switch (mp->data.opcode) {
	    case MTP_COMMAND_WHEELS:
		mp->data.mtp_payload_u.command_wheels.vleft =
		    va_arg(args, double);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_vright:
	    switch (mp->data.opcode) {
	    case MTP_COMMAND_WHEELS:
		mp->data.mtp_payload_u.command_wheels.vright =
		    va_arg(args, double);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_Acceleration:
	    switch (mp->data.opcode) {
	    case MTP_COMMAND_STARTNULL:
		mp->data.mtp_payload_u.command_startnull.acceleration =
		    va_arg(args, double);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_Timestamp:
	    switch (mp->data.opcode) {
	    case MTP_UPDATE_POSITION:
		mp->data.mtp_payload_u.update_position.position.timestamp =
		    va_arg(args, double);
		break;
	    case MTP_REQUEST_ID:
		mp->data.mtp_payload_u.request_id.position.timestamp =
		    va_arg(args, double);
		break;
	    case MTP_COMMAND_GOTO:
		mp->data.mtp_payload_u.command_goto.position.timestamp =
		    va_arg(args, double);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_Status:
	    switch (mp->data.opcode) {
	    case MTP_UPDATE_POSITION:
		mp->data.mtp_payload_u.update_position.status =
		    va_arg(args, mtp_status_t);
		break;
	    case MTP_WIGGLE_STATUS:
		mp->data.mtp_payload_u.wiggle_status.status = 
		    va_arg(args, mtp_status_t);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_RequestID:
	    mp->data.mtp_payload_u.request_id.request_id =
		va_arg(args, int);
	    break;
	case MA_CommandID:
	    switch (mp->data.opcode) {
	    case MTP_UPDATE_POSITION:
		mp->data.mtp_payload_u.update_position.command_id =
		    va_arg(args, int);
		break;
	    case MTP_COMMAND_STARTNULL: /* DAN */
		mp->data.mtp_payload_u.command_startnull.command_id =
		    va_arg(args, int);
		break;
	    case MTP_COMMAND_WHEELS:
	    case MTP_COMMAND_GOTO:
	    case MTP_COMMAND_STOP:
		mp->data.mtp_payload_u.command_goto.command_id =
		    va_arg(args, int);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	case MA_GarciaTelemetry:
	    mp->data.mtp_payload_u.telemetry.type = MTP_ROBOT_GARCIA;
	    mp->data.mtp_payload_u.telemetry.mtp_telemetry_u.garcia =
		*(va_arg(args, struct mtp_garcia_telemetry *));
	    break;
	case MA_WiggleType:
	    mp->data.mtp_payload_u.wiggle_request.wiggle_type =
		va_arg(args, mtp_wiggle_t);
	    break;
	case MA_ContactPointCount:
	    mp->data.mtp_payload_u.contact_report.count = va_arg(args, int);
	    break;
	case MA_ContactPoints:
	    cp = va_arg(args, struct contact_point *);
	    for (lpc = 0;
		 lpc < mp->data.mtp_payload_u.contact_report.count;
		 lpc++) {
		mp->data.mtp_payload_u.contact_report.points[lpc] = cp[lpc];
	    }
	    break;
	case MA_Speed:
	    switch (mp->data.opcode) {
	    case MTP_COMMAND_GOTO:
		mp->data.mtp_payload_u.command_goto.speed =
		    va_arg(args, double);
		break;
	    default:
		assert(0);
		break;
	    }
	    break;
	}
	
	tag = va_arg(args, mtp_tag_t);
    }

    if (mp->data.opcode == MTP_UPDATE_POSITION) {
	struct mtp_update_position *mup;

	mup = &mp->data.mtp_payload_u.update_position;
	if (mup->position.timestamp == 0.0) {
	    struct timeval tv;
	    
	    gettimeofday(&tv, NULL);
	    mup->position.timestamp = (double)tv.tv_sec +
		(((double)tv.tv_usec) / 100000);
	}
    }
    
    return retval;
}

mtp_error_t mtp_init_packet(struct mtp_packet *mp, mtp_tag_t tag, ...)
{
    mtp_error_t retval;
    va_list args;
    
    va_start(args, tag);
    retval = mtp_init_packetv(mp, tag, args);
    va_end(args);

    return retval;
}

mtp_error_t mtp_send_packet2(mtp_handle_t mh, mtp_tag_t tag, ...)
{
    struct mtp_packet mp;
    mtp_error_t retval;
    va_list args;
    
    va_start(args, tag);
    mtp_init_packetv(&mp, tag, args);
    va_end(args);

    retval = mtp_send_packet(mh, &mp);

    return retval;
}

void mtp_free_packet(struct mtp_packet *mp)
{
    if (mp != NULL) {
	if (mp->data.opcode != 0)
	    xdr_free(xdr_mtp_packet, (char *)mp);
    }
}

float mtp_theta(float theta)
{
    float retval;

    if (theta < -M_PI) {
	retval = theta + (2.0 * M_PI);
    }
    else if (theta > M_PI) {
	retval = theta - (2.0 * M_PI);
    }
    else {
	retval = theta;
    }

    return retval;
}

void mtp_polar(struct robot_position *current,
	       struct robot_position *dest,
	       float *r_out,
	       float *theta_out)
{
    static struct robot_position rp_zero;
    
    assert(dest != NULL);
    assert(r_out != NULL);
    assert(theta_out != NULL);
    
    if (current == NULL)
	current = &rp_zero;

    *r_out = hypotf(current->x - dest->x, current->y - dest->y);
    *theta_out = atan2f(current->y - dest->y, dest->x - current->x);
}

void mtp_cartesian(struct robot_position *current,
		   float r,
		   float theta,
		   struct robot_position *dest_out)
{
    static struct robot_position rp_zero;
    
    assert(dest_out != NULL);

    if (current == NULL)
	current = &rp_zero;
    
    dest_out->x = current->x + cos(theta) * r;
    dest_out->y = current->y - sin(theta) * r;
}

struct robot_position *mtp_world2local(struct robot_position *local_out,
				       struct robot_position *world_start,
				       struct robot_position *world_finish)
{
    float ct, st;
    
    assert(local_out != NULL);
    assert(world_start != NULL);
    assert(world_finish != NULL);
    
    ct = cosf(world_start->theta);
    st = sinf(world_start->theta);
    
    local_out->x = ct*(world_finish->x - world_start->x) +
	st*(-world_finish->y - -world_start->y);
    local_out->y = ct*(-world_finish->y - -world_start->y) +
	st*(world_start->x - world_finish->x);
    
    local_out->theta = world_finish->theta - world_start->theta;
    local_out->timestamp = world_finish->timestamp;

    return local_out;
}

int mtp_compass(float theta)
{
    int retval = 0;

#define DEGREES_30 (0.52f)
    
    theta = mtp_theta(theta);

    if ((theta >= DEGREES_30) && (theta <= (M_PI - DEGREES_30)))
	retval |= MCF_NORTH;
    
    if ((theta <= (M_PI_2 - DEGREES_30)) && (theta >= (-M_PI_2 + DEGREES_30)))
	retval |= MCF_EAST;
    
    if ((theta <= -DEGREES_30) && (theta >= (-M_PI + DEGREES_30)))
	retval |= MCF_SOUTH;
    
    if ((theta >= (M_PI_2 + DEGREES_30) || (theta <= (-M_PI + DEGREES_30))))
	retval |= MCF_WEST;
    
    return retval;
}

int mtp_dispatch(void *userdata, mtp_packet_t *mp, mtp_dispatch_tag_t tag, ...)
{
    union {
	int i;
    } values[32];
    
    int value_count = 0, value_curr = 0, match = 1, match_or = 0, retval = 0;
    mtp_dispatcher_t md;
    int done = 0;
    va_list args;
    
    assert(mp != NULL);

    va_start(args, tag);
    
    while ((tag != MD_TAG_DONE) && !done) {
	int ival, flags, command_id, match_curr = -1;
	mtp_wiggle_t mw;
	mtp_status_t ms;
	
	switch (tag & ~(MD_OR)) {
	case MD_Integer:
	    values[value_count].i = va_arg(args, int);
	    value_count += 1;
	    break;

	case MD_SkipInteger:
	    assert(value_curr < value_count);
	    
	    value_curr += 1;
	    break;
	case MD_OnInteger:
	    assert(value_curr < value_count);

	    ival = va_arg(args, int);
	    match_curr = (values[value_curr].i == ival);
	    if (!(tag & MD_OR))
		value_curr += 1;
	    break;
	case MD_OnFlags:
	    assert(value_curr < value_count);

	    flags = va_arg(args, int);
	    match_curr = ((values[value_curr].i & flags) == flags);
	    if (!(tag & MD_OR))
		value_curr += 1;
	    break;
	case MD_OnClearedFlags:
	    assert(value_curr < value_count);

	    flags = va_arg(args, int);
	    match_curr = ((values[value_curr].i & flags) == 0);
	    if (!(tag & MD_OR))
		value_curr += 1;
	    break;
	case MD_OnOpcode:
	    match_curr = (mp->data.opcode == va_arg(args, mtp_opcode_t));
	    break;
	case MD_OnStatus:
	    ms = va_arg(args, mtp_status_t);
	    switch (mp->data.opcode) {
	    case MTP_UPDATE_POSITION:
		match_curr = (mp->data.mtp_payload_u.update_position.
			      status == ms);
		break;
	    case MTP_WIGGLE_STATUS:
		match_curr = (mp->data.mtp_payload_u.wiggle_status.
			      status == ms);
		break;
	    default:
		match_curr = 0;
		break;
	    }
	    break;
	case MD_OnWiggleType:
	    mw = va_arg(args, mtp_wiggle_t);
	    if (mp->data.opcode == MTP_WIGGLE_REQUEST) {
		match_curr = (mp->data.mtp_payload_u.wiggle_request.
			      wiggle_type == mw);
	    }
	    break;
	case MD_OnCommandID:
	    command_id = va_arg(args, int);
	    switch (mp->data.opcode) {
	    case MTP_COMMAND_GOTO:
		match_curr = (mp->data.mtp_payload_u.command_goto.
			      command_id == command_id);
		break;
	    case MTP_UPDATE_POSITION:
		match_curr = (mp->data.mtp_payload_u.update_position.
			      command_id == command_id);
		break;
	    default:
		match_curr = 0;
		break;
	    }
	    break;

	case MD_Return:
	    if (match)
		done = 1;
	    match = 1;
	    match_or = 0;
	    value_curr = 0;
	    break;

	case MD_Call:
	    if (match)
		done = 1;
	    /* FALLTHROUGH */
	    
	case MD_AlsoCall:
	    md = va_arg(args, mtp_dispatcher_t);
	    if (match)
		retval = md(userdata, mp);
	    match = 1;
	    match_or = 0;
	    value_curr = 0;
	    break;
	}

	if (match_curr >= 0) {
	    if (tag & MD_OR) {
		match_or = match_or || match_curr;
	    }
	    else {
		match = match && (match_curr || match_or);
		match_or = 0;
	    }
	}
	
	tag = va_arg(args, mtp_dispatch_tag_t);
    }

    if (!done) {
	fprintf(stderr, "Unhandled packet:\n");
	mtp_print_packet(stderr, mp);
    }

    va_end(args);
    
    return retval;
}

int mtp_obstacle_config_invariant(struct obstacle_config *oc)
{
    assert(oc != NULL);
    assert(oc->xmin <= oc->xmax);
    assert(oc->ymin <= oc->ymax);
    assert(oc->zmin <= oc->zmax);

    return 1;
}

void mtp_print_packet(FILE *file, struct mtp_packet *mp)
{
    struct mtp_garcia_telemetry *mgt;
    struct mtp_contact_report *mcr;
    struct obstacle_config *oc;
    int lpc;

    assert(mp != NULL);
    assert(mtp_packet_invariant(mp));
    
    fprintf(file,
	    "Packet: version %d; role %s\n",
	    mp->vers,
	    mtp_role_strings[mp->role]);
    
    switch (mp->data.opcode) {
    case MTP_CONTROL_ERROR:
    case MTP_CONTROL_NOTIFY:
    case MTP_CONTROL_INIT:
    case MTP_CONTROL_CLOSE:
	switch (mp->data.opcode) {
	case MTP_CONTROL_ERROR:
	    fprintf(file, " opcode:\terror\n");
	    break;
	case MTP_CONTROL_NOTIFY:
	    fprintf(file, " opcode:\tnotify\n");
	    break;
	case MTP_CONTROL_INIT:
	    fprintf(file, " opcode:\tinit\n");
	    break;
	case MTP_CONTROL_CLOSE:
	    fprintf(file, " opcode:\tclose\n");
	    break;
	default:
	    assert(0);
	    break;
	}
	fprintf(file,
		"  id:\t\t%d\n"
		"  code:\t\t%d\n"
		"  msg:\t\t%s\n",
		mp->data.mtp_payload_u.error.id,
		mp->data.mtp_payload_u.error.code,
		mp->data.mtp_payload_u.error.msg);
	break;

    case MTP_CONFIG_VMC:
	fprintf(file,
		" opcode:\tconfig-vmc\n"
		"  num:\t\t%d\n",
		mp->data.mtp_payload_u.config_vmc.robots.robots_len);
	for (lpc = 0;
	     lpc < mp->data.mtp_payload_u.config_vmc.robots.robots_len;
	     lpc++) {
	    struct mtp_config_vmc *mcv = &mp->data.mtp_payload_u.config_vmc;
	    
	    fprintf(file,
		    "  robot[%d]:\t%d, %s\n",
		    lpc,
		    mcv->robots.robots_val[lpc].id,
		    mcv->robots.robots_val[lpc].hostname);
	}
	for (lpc = 0;
	     lpc < mp->data.mtp_payload_u.config_vmc.cameras.cameras_len;
	     lpc++) {
	    struct mtp_config_vmc *mcv = &mp->data.mtp_payload_u.config_vmc;
	    
	    fprintf(file,
		    "  camera[%d]:\t%s:%d %.2f %.2f %.2f %.2f -- %.2f %.2f\n",
		    lpc,
		    mcv->cameras.cameras_val[lpc].hostname,
		    mcv->cameras.cameras_val[lpc].port,
		    mcv->cameras.cameras_val[lpc].x,
		    mcv->cameras.cameras_val[lpc].y,
		    mcv->cameras.cameras_val[lpc].width,
		    mcv->cameras.cameras_val[lpc].height,
		    mcv->cameras.cameras_val[lpc].fixed_x,
		    mcv->cameras.cameras_val[lpc].fixed_y);
	}
	break;
    
    case MTP_CONFIG_VMC_CLIENT:
	fprintf(file,
		" opcode:\tconfig-vmc-client\n"
		"  fixed_x:\t\t%.2f\n"
		"  fixed_y:\t\t%.2f\n",
		mp->data.mtp_payload_u.config_vmc_client.fixed_x,
		mp->data.mtp_payload_u.config_vmc_client.fixed_y);
	break;
    
    case MTP_CONFIG_RMC:
	fprintf(file,
		" opcode:\tconfig-rmc\n"
		"  num:\t\t%d\n",
		mp->data.mtp_payload_u.config_rmc.robots.robots_len);
	for (lpc = 0;
	     lpc < mp->data.mtp_payload_u.config_rmc.robots.robots_len;
	     lpc++) {
	    struct mtp_config_rmc *mcr = &mp->data.mtp_payload_u.config_rmc;
	    
	    fprintf(file,
		    "  robot[%d]:\t%d, %s\n",
		    lpc,
		    mcr->robots.robots_val[lpc].id,
		    mcr->robots.robots_val[lpc].hostname);
	}
	for (lpc = 0;
	     lpc < mp->data.mtp_payload_u.config_rmc.bounds.bounds_len;
	     ++lpc) {
	    struct mtp_config_rmc *mcr = &mp->data.mtp_payload_u.config_rmc;
	    
	    fprintf(file,
		    "  bound[%d]:\tx=%.2f, y=%.2f, width=%.2f, height=%.2f\n",
		    lpc,
		    mcr->bounds.bounds_val[lpc].x,
		    mcr->bounds.bounds_val[lpc].y,
		    mcr->bounds.bounds_val[lpc].width,
		    mcr->bounds.bounds_val[lpc].height);
	}
	for (lpc = 0;
	     lpc < mp->data.mtp_payload_u.config_rmc.obstacles.obstacles_len;
	     lpc++) {
	    struct mtp_config_rmc *mcr = &mp->data.mtp_payload_u.config_rmc;
	    
	    fprintf(file,
		    "  obstacle[%d]:\t%d %.2f/%.2f x %.2f/%.2f\n",
		    lpc,
		    mcr->obstacles.obstacles_val[lpc].id,
		    mcr->obstacles.obstacles_val[lpc].xmin,
		    mcr->obstacles.obstacles_val[lpc].ymin,
		    mcr->obstacles.obstacles_val[lpc].xmax,
		    mcr->obstacles.obstacles_val[lpc].ymax);
	}
	break;
    
    case MTP_REQUEST_POSITION:
	fprintf(file,
		" opcode:\trequest-position\n"
		"  id:\t\t%d\n",
		mp->data.mtp_payload_u.request_position.robot_id);
	break;
    
    case MTP_REQUEST_ID:
	fprintf(file,
		" opcode:\trequest-id\n"
		"  request_id:\t%d\n"
		"  x:\t\t%f\n"
		"  y:\t\t%f\n"
		"  theta:\t%f\n"
		"  timestamp:\t%f\n",
		mp->data.mtp_payload_u.request_id.request_id,
		mp->data.mtp_payload_u.request_id.position.x,
		mp->data.mtp_payload_u.request_id.position.y,
		mp->data.mtp_payload_u.request_id.position.theta,
		mp->data.mtp_payload_u.request_id.position.timestamp);
	break;
    
    case MTP_UPDATE_POSITION:
	fprintf(file,
		" opcode:\tupdate-position\n"
		"  id:\t\t%d\n"
		"  x:\t\t%f\n"
		"  y:\t\t%f\n"
		"  theta:\t%f\n"
		"  status:\t%s\n"
		"  timestamp:\t%f\n"
		"  command_id:\t%d\n",
		mp->data.mtp_payload_u.update_position.robot_id,
		mp->data.mtp_payload_u.update_position.position.x,
		mp->data.mtp_payload_u.update_position.position.y,
		mp->data.mtp_payload_u.update_position.position.theta,
		((mp->data.mtp_payload_u.update_position.status ==
		  MTP_POSITION_STATUS_CYCLE_COMPLETE) ?
		 "cycle-complete" :
		 mtp_status_strings[mp->data.mtp_payload_u.update_position.
				   status + 1]),
		mp->data.mtp_payload_u.update_position.position.timestamp,
		mp->data.mtp_payload_u.update_position.command_id);
	break;
    
    case MTP_UPDATE_ID:
	fprintf(file,
		" opcode:\tupdate-id\n"
		"  request_id:\t%d\n"
		"  id:\t%d\n",
		mp->data.mtp_payload_u.update_id.request_id,
		mp->data.mtp_payload_u.update_id.robot_id);
	break;
    
    case MTP_COMMAND_GOTO:
	fprintf(file,
		" opcode:\tcommand-goto\n"
		"  commid:\t%d\n"
		"  id:\t\t%d\n"
		"  x:\t\t%f\n"
		"  y:\t\t%f\n"
		"  theta:\t%f\n"
		"  timestamp:\t%f\n"
		"  speed:\t%.2f\n",
		mp->data.mtp_payload_u.command_goto.command_id,
		mp->data.mtp_payload_u.command_goto.robot_id,
		mp->data.mtp_payload_u.command_goto.position.x,
		mp->data.mtp_payload_u.command_goto.position.y,
		mp->data.mtp_payload_u.command_goto.position.theta,
		mp->data.mtp_payload_u.command_goto.position.timestamp,
		mp->data.mtp_payload_u.command_goto.speed);
	break;
    
    case MTP_COMMAND_STOP:
	fprintf(file,
		" opcode:\tcommand-stop\n"
		"  commid:\t%d\n"
		"  id:\t%d\n",
		mp->data.mtp_payload_u.command_stop.command_id,
		mp->data.mtp_payload_u.command_stop.robot_id);
	break;

    case MTP_COMMAND_STARTNULL:
	fprintf(file,
		" opcode:\tcommand-startnull\n"
		"  commid:\t%d\n"
		"  id:\t%d\n"
		"  accel:\t%.3f\n",
		mp->data.mtp_payload_u.command_startnull.command_id,
		mp->data.mtp_payload_u.command_startnull.robot_id,
		(double)mp->data.mtp_payload_u.command_startnull.acceleration);
	break;

    case MTP_COMMAND_WHEELS:
	fprintf(file,
		" opcode:\tcommand-wheels\n"
		"  commid:\t%d\n"
		"  robot:\t%d\n"
		"  vleft:\t%.3f\n"
		"  vright:\t%.3f\n",
		mp->data.mtp_payload_u.command_wheels.command_id,
		mp->data.mtp_payload_u.command_wheels.robot_id,
		mp->data.mtp_payload_u.command_wheels.vleft,
		mp->data.mtp_payload_u.command_wheels.vright);
	break;

    case MTP_TELEMETRY:
	fprintf(file,
		" opcode:\ttelemetry - %d\n",
		mp->data.mtp_payload_u.telemetry.type);
	switch (mp->data.mtp_payload_u.telemetry.type) {
	case MTP_ROBOT_GARCIA:
	    mgt = &mp->data.mtp_payload_u.telemetry.mtp_telemetry_u.garcia;
	    fprintf(file,
		    "  battery_level:\t%f\n"
		    "  battery_voltage:\t%f\n"
		    "  battery_misses:\t%d\n"
		    "  left_odometer:\t%f\n"
		    "  right_odometer:\t%f\n"
		    "  left_instant_odom:\t%f\n"
		    "  right_instant_odom:\t%f\n"
		    "  left_velocity:\t%f\n"
		    "  right_velocity:\t%f\n"
		    "  move_count:\t\t%u\n"
		    "  move_time:\t\t%d.%d\n"
		    "  down_ranger_left:\t%d\n"
		    "  down_ranger_right:\t%d\n"
		    "  front_ranger_left:\t%f\n"
		    "  front_ranger_right:\t%f\n"
		    "  front_ranger_thresh:\t%f\n"
		    "  rear_ranger_left:\t%f\n"
		    "  rear_ranger_right:\t%f\n"
		    "  rear_ranger_thresh:\t%f\n"
		    "  side_ranger_left:\t%f\n"
		    "  side_ranger_right:\t%f\n"
		    "  side_ranger_thresh:\t%f\n"
		    "  speed:\t\t%f\n"
		    "  status:\t\t%d\n"
		    "  user_button:\t\t%d\n"
		    "  user_led:\t\t%d\n"
		    "  stall_contact:\t\t%d\n",
		    mgt->battery_level,
		    mgt->battery_voltage,
		    mgt->battery_misses,
		    mgt->left_odometer,
		    mgt->right_odometer,
		    mgt->left_instant_odometer,
		    mgt->right_instant_odometer,
		    mgt->left_velocity,
		    mgt->right_velocity,
		    mgt->move_count,
		    mgt->move_time_sec, mgt->move_time_usec,
		    mgt->down_ranger_left,
		    mgt->down_ranger_right,
		    mgt->front_ranger_left,
		    mgt->front_ranger_right,
		    mgt->front_ranger_threshold,
		    mgt->rear_ranger_left,
		    mgt->rear_ranger_right,
		    mgt->rear_ranger_threshold,
		    mgt->side_ranger_left,
		    mgt->side_ranger_right,
		    mgt->side_ranger_threshold,
		    mgt->speed,
		    mgt->status,
		    mgt->user_button,
		    mgt->user_led,
		    mgt->stall_contact);
	    break;
	}
	break;
	
    case MTP_WIGGLE_REQUEST:
	fprintf(file,
		" opcode:\twiggle-request\n"
		"  id:\t%d\n",
		mp->data.mtp_payload_u.wiggle_request.robot_id
		);
	switch (mp->data.mtp_payload_u.wiggle_request.wiggle_type) {
	case MTP_WIGGLE_START:
	    fprintf(file,
		    "  wiggle_type:\tstart\n"
		    );
	    break;
	case MTP_WIGGLE_180_R:
	    fprintf(file,
		    "  wiggle_type:\t180deg right\n"
		    );
	    break;
	case MTP_WIGGLE_180_R_L:
	    fprintf(file,
		    "  wiggle_type:\t180deg right, 180deg left\n"
		    );
	    break;
	case MTP_WIGGLE_360_R:
	    fprintf(file,
		    "  wiggle_type:\t360deg right\n"
		    );
	    break;
	case MTP_WIGGLE_360_R_L:
	    fprintf(file,
		    "  wiggle_type:\t360deg right, 360deg left\n"
		    );
	    break;
	default:
	    assert(0);
	    break;
	}
	break;
    case MTP_WIGGLE_STATUS:
	fprintf(file,
		" opcode:\twiggle-status\n"
		"  id:\t\t%d\n"
		"  status:\t%s\n",
		mp->data.mtp_payload_u.wiggle_status.robot_id,
		((mp->data.mtp_payload_u.wiggle_status.status ==
		  MTP_POSITION_STATUS_CYCLE_COMPLETE) ?
		 "cycle-complete" :
		 mtp_status_strings[mp->data.mtp_payload_u.wiggle_status.
				   status + 1]));
	break;
	
    case MTP_REQUEST_REPORT:
	fprintf(file,
		" opcode:\trequest-report\n"
		"  id:\t\t%d\n",
		mp->data.mtp_payload_u.request_report.robot_id);
	break;

    case MTP_CONTACT_REPORT:
	mcr = &mp->data.mtp_payload_u.contact_report;
	fprintf(file,
		" opcode:\tcontact-report\n"
		"  count:\t%d\n",
		mcr->count);
	for (lpc = 0; lpc < mcr->count; lpc++) {
	    fprintf(file,
		    "  contact[%d]:\t%f %f\n",
		    lpc,
		    mcr->points[lpc].x,
		    mcr->points[lpc].y);
	}
	break;

    case MTP_CREATE_OBSTACLE:
	oc = &mp->data.mtp_payload_u.create_obstacle.config;
	fprintf(file,
		" opcode:\tcreate-obstacle\n"
		"  robot-id: %d\n"
		"  id: %d\n"
		"  bounds: %.2f %.2f %.2f %.2f\n",
		mp->data.mtp_payload_u.create_obstacle.robot_id,
		oc->id,
		oc->xmin, oc->ymin, oc->xmax, oc->ymax);
	break;
	
    case MTP_UPDATE_OBSTACLE:
	oc = &mp->data.mtp_payload_u.update_obstacle;
	fprintf(file,
		" opcode:\tupdate-obstacle\n"
		"  id: %d\n"
		"  bounds: %.2f %.2f %.2f %.2f\n",
		oc->id,
		oc->xmin, oc->ymin, oc->xmax, oc->ymax);
	break;
	
    case MTP_REMOVE_OBSTACLE:
	fprintf(file,
		" opcode:\tremove-obstacle\n"
		"  id: %d\n",
		mp->data.mtp_payload_u.remove_obstacle);
	break;
	
    default:
	printf("%p %d\n", &mp->data.opcode, mp->data.opcode);
	fprintf(stderr, "error: unknown opcode %d\n", mp->data.opcode);
	assert(0);
	break;
    }
}
