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

package com.flack.geni.resources.virt
{
	import com.flack.geni.resources.Extensions;

	/**
	 * IP Address
	 * 
	 * @author mstrum
	 * 
	 */
	public class Ip
	{
		public var address:String;
		public var netmask:String = "";
		public var type:String = "";
		public var bound:Boolean = false;
		
		public var extensions:Extensions = new Extensions();
		
		/**
		 * 
		 * @param newAddress String representation of the address
		 * 
		 */
		public function Ip(newAddress:String = "")
		{
			address = newAddress;
		}
		
		public function get Base():uint
		{
			var netmaskSubparts:Array = netmask.split('.');
			var baseSubparts:Array = netmask.split('.');
			
			var ipBase:uint = 0;
			for(var i:int = netmaskSubparts.length-1; i > -1; i--)
			{
				var netmaskSubpart:uint = new uint(netmaskSubparts[i]);
				var baseSubpart:uint = new uint(baseSubparts[i]);
				ipBase |= (((netmaskSubpart & baseSubpart) & 0xFF) << i*8);
			}
			
			return ipBase;
		}
		
		public function get Space():uint
		{
			var netmaskSubparts:Array = netmask.split('.');
			var baseSubparts:Array = netmask.split('.');
			
			var ipSpace:uint = 0;
			for(var i:int = netmaskSubparts.length-1; i > -1; i--)
			{
				var netmaskSubpart:uint = new uint(netmaskSubparts[i]);
				ipSpace |= (((~netmaskSubpart) & 0xFF) << i*8);
			}
			return ipSpace;
		}
	}
}