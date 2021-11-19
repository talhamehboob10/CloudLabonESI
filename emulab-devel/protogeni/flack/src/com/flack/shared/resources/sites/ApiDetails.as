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

package com.flack.shared.resources.sites
{
	/**
	 * Details related to the API
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ApiDetails
	{
		// What interface is used?
		public static const API_GENIAM:int = 0;
		public static const API_PROTOGENI:int = 1;
		public static const API_SFA:int = 2;
		public static const API_EMULAB:int = 3;
		public static const API_NOTSET:int = 4;
		
		// ProtoGENI levels
		public static const LEVEL_MINIMAL:int = 0;
		public static const LEVEL_FULL:int = 1;
		
		public var type:int;
		public var version:Number;
		public var url:String;
		public var level:int;
		
		/**
		 * 
		 * @param newType Type
		 * @param newVersion Version
		 * @param newUrl URL
		 * @param newLevel Level
		 * 
		 */
		public function ApiDetails(newType:int = API_NOTSET,
								   newVersion:Number = NaN,
								   newUrl:String = "",
								   newLevel:int = 0)
		{
			type = newType;
			version = newVersion;
			url = newUrl;
			level = newLevel;
		}
		
		public function equals(other:ApiDetails):Boolean
		{
			return type == other.type &&
				version == other.version &&
				url == other.url &&
				level == other.level;
		}
		
		public function get ReadableString():String
		{
			return toString();
		}
		
		public function toString():String
		{
			var result:String = "";
			switch(type)
			{
				case ApiDetails.API_GENIAM:
					result = "GENI AM";
					break;
				case ApiDetails.API_PROTOGENI:
					result = "ProtoGENI";
					if(level == ApiDetails.LEVEL_FULL)
						result += " (full)";
					else
						result += " (minimal)";
					break;
				case ApiDetails.API_SFA:
					result = "SFA";
					break;
				case ApiDetails.API_EMULAB:
					result = "Emulab";
					break;
				case ApiDetails.API_NOTSET:
					result = "Not set";
					break;
				default:
					result = "Unknown";
			}
			
			if(version)
				result += " v" + version;
			
			return result;
		}
	}
}