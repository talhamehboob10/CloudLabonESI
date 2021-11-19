/*
 * Copyright (c) 2009 University of Utah and the Flux Group.
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
 
 package protogeni.resources
{
	import mx.collections.ArrayCollection;
	
	// Interface on a physical node
	public class PhysicalNodeInterface
	{
		public static var CONTROL:int = 0;
		public static var EXPERIMENTAL:int = 1;
		public static var UNUSED:int = 2;
		public static var UNUSED_CONTROL:int = 3;
		public static var UNUSED_EXPERIMENTAL:int = 4;
		
		public static function RoleStringFromInt(i:int):String
		{
			switch(i)
			{
				case CONTROL: return "control";
				case EXPERIMENTAL: return "experimental";
				case UNUSED: return "unused";
				case UNUSED_CONTROL: return "unused_control";
				case UNUSED_EXPERIMENTAL: return "unused_experimental";
				default: return "";
			}
		}
		
		public static function RoleIntFromString(s:String):int
		{
			switch(s)
			{
				case "control": return CONTROL;
				case "experimental": return EXPERIMENTAL;
				case "unused": return UNUSED;
				case "unused_control": return UNUSED_CONTROL;
				case "unused_experimental": return UNUSED_EXPERIMENTAL;
				default: return -1;
			}
		}
		
		public function PhysicalNodeInterface(own:PhysicalNode)
		{
			owner = own;
		}
		
		[Bindable]
		public var owner:PhysicalNode;
		
		[Bindable]
		public var id:String;
		
		public var role : int = -1;

		[Bindable]
		public var links:ArrayCollection = new ArrayCollection();
		
		
	}
}