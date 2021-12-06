/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * 
 * {{{GENIPUBLIC-LICENSE
 * 
 * GENI Public License
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and/or hardware specification (the "Work") to
 * deal in the Work without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Work, and to permit persons to whom the Work
 * is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Work.
 * 
 * THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
 * IN THE WORK.
 * 
 * }}}
 */

package com.flack.geni.resources
{
	import com.flack.geni.resources.physical.PhysicalInterface;
	import com.flack.geni.resources.virt.VirtualInterface;
	import com.flack.shared.utils.NetUtil;

	/**
	 * Property of path from a source interface to a destination interface (one way) in a link
	 * 
	 * @author mstrum
	 * 
	 */
	public class Property
	{
		/**
		 * VirtualInterface OR PhysicalInterface
		 */
		public var source:*;
		/**
		 * VirtualInterface OR PhysicalInterface
		 */
		public var destination:*;
		
		public var capacity:Number;
		public function get CapacityDescription():String
		{
			return NetUtil.kbsToString(capacity);
		}
		
		public var packetLoss:Number;
		public function get PacketLossDescription():String
		{
			return (packetLoss*100) + "%";
		}
		
		public var latency:Number;
		public function get LatencyDescription():String
		{
			return latency + "ms";
		}
		
		public var extensions:Extensions = new Extensions();
		
		/**
		 * 
		 * @param newSource Source virtual or physical interface
		 * @param newDestination Destination virtual or physical interface
		 * @param newCapacity Capacity
		 * @param newPacketLoss Packet loss
		 * @param newLatency Latency
		 * 
		 */
		public function Property(newSource:* = null,
									 newDestination:* = null,
									 newCapacity:Number = 0,
									 newPacketLoss:Number = 0,
									 newLatency:Number = 0)
		{
			source = newSource;
			destination = newDestination;
			capacity = newCapacity;
			packetLoss = newPacketLoss;
			latency = newLatency;
		}
		
		public function toString():String
		{
			if(source is VirtualInterface)
				return "[Property\n\t\t\t\tSource="+(source as VirtualInterface).clientId+",\n\t\t\t\tDest="+(destination as VirtualInterface).clientId+",\n\t\t\t\tCapacity="+capacity+",\n\t\t\t\tPacketLoss="+packetLoss+",\n\t\t\t\tLatency="+latency+" /]";
			else
				return "[Property\n\t\t\t\tSource="+(source as PhysicalInterface).id.name+",\n\t\t\t\tDest="+(destination as PhysicalInterface).id.name+",\n\t\t\t\tCapacity="+capacity+",\n\t\t\t\tPacketLoss="+packetLoss+",\n\t\t\t\tLatency="+latency+" /]";
				
		}
	}
}