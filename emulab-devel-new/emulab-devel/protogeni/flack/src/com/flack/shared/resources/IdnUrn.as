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

package com.flack.shared.resources
{
	/**
	 * Unique resource identifier in the form: urn:publicid:IDN+authority+type+name
	 * 
	 * @author mstrum
	 * 
	 */
	public class IdnUrn
	{
		// Common types
		static public const TYPE_USER:String = "user";
		static public const TYPE_SLICE:String = "slice";
		static public const TYPE_SLIVER:String = "sliver";
		static public const TYPE_AUTHORITY:String = "authority";
		static public const TYPE_NODE:String = "node";
		static public const TYPE_INTERFACE:String = "interface";
		static public const TYPE_LINK:String = "link";
		
		/**
		 * 
		 * @return String representation including everything
		 * 
		 */
		[Bindable]
		public var full:String;
		
		public function get authority():String
		{
			var splits:Array = full.split("+");
			if(splits.length == 4)
				return splits[1];
			else
				return "";
		}
		
		public function get type():String
		{
			var splits:Array = full.split("+");
			if(splits.length == 4)
				return splits[2];
			else
				return "";
		}
		
		public function get name():String
		{
			var splits:Array = full.split("+");
			if(splits.length == 4)
				return splits[3];
			else
				return "";
		}
		
		public function IdnUrn(urn:String = "")
		{
			if(urn == null)
				full = "";
			else
				full = urn;
		}
		
		public function toString():String
		{
			return full;
		}
		
		public static function getAuthorityFrom(urn:String):String
		{
			return urn.split("+")[1];
		}
		
		public static function getTypeFrom(urn:String):String
		{
			return urn.split("+")[2];
		}
		
		public static function getNameFrom(urn:String):String
		{
			return urn.split("+")[3];
		}
		
		/**
		 * 
		 * @param newAuthority Authority portion of a IDN-URN
		 * @param newType Type portion of a IDN-URN
		 * @param newName Name portion of a IDN-URN
		 * @return 
		 * 
		 */
		public static function makeFrom(newAuthority:String,
										newType:String,
										newName:String):IdnUrn
		{
			return new IdnUrn("urn:publicid:IDN+" + newAuthority + "+" + newType + "+" + newName);
		}
		
		/**
		 * 
		 * @param testString String to see if it is a valid IDN-URN
		 * @return TRUE if a valid IDN-URN
		 * 
		 */
		public static function isIdnUrn(testString:String):Boolean
		{
			try
			{
				var array:Array = testString.split("+");
				if(array[0] != "urn:publicid:IDN")
					return false;
				if(array.length != 4)
					return false;
			}
			catch(e:Error)
			{
				return false;
			}
			return true;
		}
		
		/**
		 * Splits things like plc:princeton:mstrum into an array. This is commonly used for hierarchical elements
		 * 
		 * @param element Element to get subelements
		 * @return 
		 * 
		 */
		public static function splitElement(element:String):Array
		{
			return element.split(':');
		}
	}
}