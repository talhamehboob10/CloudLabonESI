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

import java.util.*;
import net.tinyos.message.Message;

public class LogPacket {

    private Date timeStamp;
    private byte[] data;
    private int packetType;
    private int crc;
    private Object msg;
    private String srcVnodeName;

    public LogPacket(String srcVnodeName,Date time,byte[] data,
		     int packetType,int crc) {
	this.srcVnodeName = srcVnodeName;
	this.timeStamp = time;
	this.data = data;
	this.packetType = packetType;
	this.crc = crc;
	//this.msg = null;
    }

    public Date getTimeStamp() {
	return this.timeStamp;
    }

    public byte[] getData() {
	return this.data;
    }

    public int getLowLevelPacketType() {
	return this.packetType;
    }

    public int getLowLevelCRC() {
	return this.crc;
    }

    public String getSrcVnodeName() {
	return this.srcVnodeName;
    }

    public void setMsgObject(Object obj) {
	this.msg = obj;
    }

    public Object getMsgObject() {
	return this.msg;
    }

}
