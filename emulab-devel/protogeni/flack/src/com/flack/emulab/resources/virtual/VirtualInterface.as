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

package com.flack.emulab.resources.virtual
{
	import com.flack.emulab.resources.NamedObject;
	
	public class VirtualInterface extends NamedObject
	{
		public var node:VirtualNode;
		public var link:VirtualLink;
		public var ip:String = "";
		public var physicalName:String = ""; // usually not set
		
		public var queue:Queue = null; // queue from this interface out
		
		public var tracing:String = "";
		public var filter:String = "";
		public var captureLength:int = -1;
		
		public var bandwidthFrom:Number = 100000; //kbs
		public var latencyFrom:Number = 0; //ms
		public var lossRateFrom:Number = 0; //out of 1
		// LAN ONLY
		public var bandwidthTo:Number = 100000; //kbs
		public var latencyTo:Number = 0; //ms
		public var lossRateTo:Number = 0; //out of 1
		
		public function VirtualInterface(newNode:VirtualNode, newName:String="")
		{
			super(newName);
			node = newNode;
		}
	}
}