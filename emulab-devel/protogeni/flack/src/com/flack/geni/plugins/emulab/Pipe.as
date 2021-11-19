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

package com.flack.geni.plugins.emulab
{
	import com.flack.geni.resources.virt.VirtualInterface;

	/**
	 * Pipe used within a delay node to edit network properties from one interface to another
	 * 
	 * @author mstrum
	 * 
	 */
	public class Pipe
	{
		public var src:VirtualInterface;
		public var dst:VirtualInterface;
		
		public var capacity:Number;
		public var latency:Number;
		public var packetLoss:Number;
		
		/**
		 * 
		 * @param newSource Source interface
		 * @param newDestination Destination interface
		 * @param newCapacity Capacity
		 * @param newLatency Latency
		 * @param newPacketLoss Packet loss
		 * 
		 */
		public function Pipe(newSource:VirtualInterface,
							 newDestination:VirtualInterface,
							 newCapacity:Number = NaN,
							 newLatency:Number = NaN,
							 newPacketLoss:Number = NaN)
		{
			src = newSource;
			dst = newDestination;
			capacity = newCapacity;
			latency = newLatency;
			packetLoss = newPacketLoss;
		}
	}
}