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
	import com.flack.geni.plugins.RspecProcessInterface;
	import com.flack.geni.plugins.SliverTypeInterface;
	
	import flash.utils.Dictionary;

	public class SliverTypes
	{
		// V1
		public static var EMULAB_VNODE:String = "emulab-vnode";
		
		// Reference CM
		static public var QEMUPC:String = "qemu-pc"
		
		static public var XEN_VM:String = "xen-vm";
		
		private static var sliverTypeToInterface:Dictionary = new Dictionary();
		public static function addSliverTypeInterface(name:String, iface:SliverTypeInterface):void
		{
			sliverTypeToInterface[name] = iface;
		}
		public static function getSliverTypeInterface(name:String):SliverTypeInterface
		{
			return sliverTypeToInterface[name];
		}
		
		// XXX ugly, ugly, ugly ... but will do for now
		private static var rspecProcessToInterface:Dictionary = new Dictionary();
		public static function addRspecProcessInterface(name:String, iface:RspecProcessInterface):void
		{
			rspecProcessToInterface[name] = iface;
		}
		public static function getRspecProcessInterface(name:String):RspecProcessInterface
		{
			return rspecProcessToInterface[name];
		}
		
	}
}