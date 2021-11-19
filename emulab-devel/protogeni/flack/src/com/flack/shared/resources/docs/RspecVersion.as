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

package com.flack.shared.resources.docs
{
	/**
	 * Type information about an rspec format
	 * 
	 * @author mstrum
	 * 
	 */
	public class RspecVersion
	{
		// Types
		public static const TYPE_PROTOGENI:String = "protogeni";
		public static const TYPE_GENI:String = "geni";
		public static const TYPE_SFA:String = "sfa";
		public static const TYPE_ORCA:String = "orca";
		public static const TYPE_OPENFLOW:String = "openflow";
		public static const TYPE_ORBIT:String = "orbit";
		public static const TYPE_EMULAB:String = "emulab";
		public static const TYPE_INVALID:String = "invalid";
		public static function typeToShort(type:String):String
		{
			switch(type)
			{
				case TYPE_PROTOGENI: return"PG";
				case TYPE_GENI: return "GENI";
				case TYPE_SFA: return "SFA";
				case TYPE_ORCA: return "ORCA";
				case TYPE_OPENFLOW: return "OF";
				case TYPE_ORBIT: return "ORBIT";
				case TYPE_EMULAB: return "Emulab";
				case TYPE_INVALID:
				default:
					return "??";
			}
		}
		
		/**
		 * What type is the RSPEC? (ProtoGENI, GENI, etc.)
		 */
		public var type:String;
		[Bindable]
		public var version:Number;
		/**
		 * 
		 * @return Very short string representation (eg. PGv2)
		 * 
		 */
		public function get ShortString():String
		{
			return RspecVersion.typeToShort(type) + "v" + version.toString();
		}
		
		/**
		 * 
		 * @param newType Type of RSPEC
		 * @param newVersion RSPEC Version
		 * 
		 */
		public function RspecVersion(newType:String,
									 newVersion:Number = NaN)
		{
			type = newType;
			version = newVersion;
		}
		
		public function toString():String
		{
			return "[RspecVersion Type="+type+", Version="+version+"]";
		}
	}
}