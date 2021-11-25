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

package com.flack.geni.resources.virt.extensions
{
	import com.flack.shared.SharedMain;
	
	import flash.system.Capabilities;
	
	import mx.core.FlexGlobals;

	/**
	 * Client Info extension
	 * 
	 * @author mstrum
	 * 
	 */
	public class ClientInfo
	{
		public var name:String;	
		
		/**
		 * Flash, OS, Arch, etc.
		 */
		public var environment:String;
		
		public var version:String;
		
		public var url:String;
		
		public function ClientInfo()
		{
			name = "Flack";
			version = SharedMain.version;
			environment = "Flash Version: " + Capabilities.version + ", OS: " + Capabilities.os + ", Arch: " + Capabilities.cpuArchitecture + ", Screen: " + Capabilities.screenResolutionX + "x" + Capabilities.screenResolutionY+" @ "+Capabilities.screenDPI+" DPI with touchscreen type "+Capabilities.touchscreenType;
			url = FlexGlobals.topLevelApplication.url;
		}
		
		public function toString():String
		{
			return "Client Name: " + name + "\nClient Version: "+ version + "\nClient Environment: "+environment + "\nClient URL: " + url;
		}
	}
}