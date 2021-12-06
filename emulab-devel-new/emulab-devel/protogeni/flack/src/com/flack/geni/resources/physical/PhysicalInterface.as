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

package com.flack.geni.resources.physical
{
	import com.flack.shared.resources.IdentifiableObject;

	/**
	 * Interface on a resource which is typically used to connect to links
	 * 
	 * @author mstrum
	 * 
	 */
	public class PhysicalInterface extends IdentifiableObject
	{
		public static const ROLE_CONTROL:int = 0;
		public static const ROLE_EXPERIMENTAL:int = 1;
		public static const ROLE_UNUSED:int = 2;
		public static const ROLE_UNUSED_CONTROL:int = 3;
		public static const ROLE_UNUSED_EXPERIMENTAL:int = 4;
		public static const ROLE_PORT:int = 5;
		public static function RoleStringFromInt(i:int):String
		{
			switch(i)
			{
				case ROLE_CONTROL: return "control";
				case ROLE_EXPERIMENTAL: return "experimental";
				case ROLE_UNUSED: return "unused";
				case ROLE_UNUSED_CONTROL: return "unused_control";
				case ROLE_UNUSED_EXPERIMENTAL: return "unused_experimental";
				case ROLE_UNUSED_EXPERIMENTAL: return "port";
				default: return "";
			}
		}
		public static function RoleIntFromString(s:String):int
		{
			switch(s)
			{
				case "control": return ROLE_CONTROL;
				case "experimental": return ROLE_EXPERIMENTAL;
				case "unused": return ROLE_UNUSED;
				case "unused_control": return ROLE_UNUSED_CONTROL;
				case "unused_experimental": return ROLE_UNUSED_EXPERIMENTAL;
				case "port": return ROLE_UNUSED_EXPERIMENTAL;
				default: return -1;
			}
		}
		
		public function get Name():String
		{
			return id.name;
		}
		
		[Bindable]
		public var owner:PhysicalNode;
		
		public var role:int = -1;
		public var publicIPv4:String = "";
		public var num:Number;
		
		[Bindable]
		public var links:PhysicalLinkCollection;
		
		/**
		 * 
		 * @param own Owner node
		 * 
		 */
		public function PhysicalInterface(own:PhysicalNode)
		{
			super();
			links = new PhysicalLinkCollection();
			owner = own;
		}
		
		override public function toString():String
		{
			return "[Interface ID="+id.full+"]";
		}
	}
}