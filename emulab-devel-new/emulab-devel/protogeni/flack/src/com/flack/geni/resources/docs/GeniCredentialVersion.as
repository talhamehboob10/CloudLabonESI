/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * 
 * {{{GENIPUBLIC-LICENSE
 * 
 * GENI Public License
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and/or hardware specification (the "Work") to
 * deal in the Work without restriction, including without limitation
 * the
 * rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Work, and to permit persons to whom the
 * Work
 * is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Work.
 * 
 * THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR
 * OTHER DEALINGS
 * IN THE WORK.
 * 
 * }}}
 */

package com.flack.geni.resources.docs
{
	/**
	 * Type information about a credential format
	 * 
	 * @author mstrum
	 * 
	 */
	public class GeniCredentialVersion
	{
		// Types
		public static const TYPE_SFA:String = "geni_sfa";
		public static const TYPE_ABAC:String = "geni_abac";
		public static const TYPE_UNKNOWN:String = "";
		public static function typeToShort(type:String):String
		{
			switch(type)
			{
				case TYPE_SFA: return"SFA";
				case TYPE_ABAC: return "ABAC";
				case TYPE_UNKNOWN: return "Unknown";
				default:
					return "??";
			}
		}
		
		public static function get Default():GeniCredentialVersion
		{
			return new GeniCredentialVersion(TYPE_SFA, 2);
		}
		
		/**
		 * What type is the credential? (SFA, ABAC, etc.)
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
			return GeniCredentialVersion.typeToShort(type) + "v" + version.toString();
		}
		
		/**
		 * 
		 * @param newType Type of credential
		 * @param newVersion Credential version
		 * 
		 */
		public function GeniCredentialVersion(newType:String,
									 newVersion:Number = NaN)
		{
			type = newType;
			version = newVersion;
		}
		
		public function toString():String
		{
			return "[GeniCredentialVersion Type="+type+", Version="+version+"]";
		}
	}
}