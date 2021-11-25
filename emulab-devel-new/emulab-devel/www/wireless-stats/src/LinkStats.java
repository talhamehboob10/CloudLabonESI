/*
 * Copyright (c) 2006-2007 University of Utah and the Flux Group.
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

public class LinkStats {
    private String srcNode;
    private String recvNode;
    private int pktRecvCount;
    private int pktCount;
    private float pktPercent;
    private float minRSSI;
    private float maxRSSI;
    private float avgRSSI;
    private float stddevRSSI;
    
    public LinkStats(String srcNode,String recvNode,
                     int pktRecvCount,int pktCount,
                     float minRSSI,float maxRSSI,float avgRSSI,
                     float stddevRSSI) {
        this.srcNode = srcNode;
        this.recvNode = recvNode;
        this.pktRecvCount = pktRecvCount;
        this.pktCount = pktCount;
        this.pktPercent = ((float)this.pktRecvCount)/this.pktCount;
        this.minRSSI = minRSSI;
        this.maxRSSI = maxRSSI;
        this.avgRSSI = avgRSSI;
        this.stddevRSSI = stddevRSSI;
    }
    
    public String getSrcNode() {
        return srcNode;
    }
    
    public String getRecvNode() {
        return recvNode;
    }
    
    public int getPktCount() {
        return pktRecvCount;
    }
    
    public int getExpectedPktCount() {
        return pktCount;
    }
    
    public float getPktPercent() {
        return pktPercent;
    }
    
    public float getMinRSSI() {
        return minRSSI;
    }
    
    public float getMaxRSSI() {
        return maxRSSI;
    }
    
    public float getAvgRSSI() {
        return avgRSSI;
    }
    
    public float getStddevRSSI() {
        return stddevRSSI;
    } 
}