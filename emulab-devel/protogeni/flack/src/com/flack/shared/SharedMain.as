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

package com.flack.shared
{
	import com.flack.emulab.EmulabMain;
	import com.flack.geni.GeniMain;
	import com.flack.shared.logging.Logger;
	import com.flack.shared.resources.FlackUser;
	import com.flack.shared.tasks.Tasker;
	import com.mattism.http.xmlrpc.JSLoader;
        import flash.external.ExternalInterface;
	
	import flash.system.Capabilities;
	
	import mx.core.FlexGlobals;
	
	/**
	 * Global container for things we use
	 * 
	 * @author mstrum
	 * 
	 */
	public class SharedMain
	{
		/**
		 * Flack version
		 */
		public static const version:String = "v17.20";
		
		public static const MODE_GENI:int = 0;
		public static const MODE_EMULAB:int = 1;
		
		public static var mode:int = MODE_GENI;
		public static function preinitMode():void
		{
			switch(mode)
			{
				case MODE_EMULAB:
					EmulabMain.preinitMode();
					break;
				default:
					GeniMain.preinitMode();
			}
		}
		public static function initMode():void
		{
			switch(mode)
			{
				case MODE_EMULAB:
					EmulabMain.initMode();
					break;
				default:
					GeniMain.initMode();
			}
			
		}
		public static function loadParams():void
		{
			switch(mode)
			{
				case MODE_EMULAB:
					EmulabMain.loadParams();
					break;
				default:
					GeniMain.loadParams();
			}
		}
		
		public static function initPlugins():void
		{
			switch(mode)
			{
				case MODE_EMULAB:
					EmulabMain.initPlugins();
					break;
				default:
					GeniMain.initPlugins();
			}
		}
		
		public static function runFirst():void
		{
			switch(mode)
			{
				case MODE_EMULAB:
					EmulabMain.runFirst();
					break;
				default:
					GeniMain.runFirst();
			}
		}

		public static function logToJS(message : String):void
		{
			ExternalInterface.call("logToConsole", message);
		}
		
		/**
		 * Dispatches all geni events
		 */
		public static var sharedDispatcher:FlackDispatcher = new FlackDispatcher();
		
		/**
		 * All logs of what has happened in Flack
		 */
		public static var logger:Logger = new Logger();
		
		public static var tasker:Tasker = new Tasker();
		
		[Bindable]
		public static var user:FlackUser;
		
		[Bindable]
		private static var bundle:String = "";
		/**
		 * Sets the SSL Cert bundle here and in Forge
		 * 
		 * @param value New SSL Cert bundle to use
		 * 
		 */
		public static function set Bundle(value:String):void
		{
			bundle = value;
			SharedCache.updateCertBundle(value);
			if(GeniMain.bundlePreset) {
				JSLoader.addServerCertificate(value);
			} else {
				JSLoader.setServerCertificate(value);
			}
		}
		/**
		 * 
		 * @return SSL Cert bundle being used
		 * 
		 */
		[Bindable]
		public static function get Bundle():String
		{
			return bundle;
		}
		
		public static function get ClientString():String
		{
			return "Client: Flack\n"
				+"Version: "+ version + "\n"
				+"Flash Version: " + Capabilities.version + ", OS: " + Capabilities.os + ", Arch: " + Capabilities.cpuArchitecture + ", Screen: " + Capabilities.screenResolutionX + "x" + Capabilities.screenResolutionY+" @ "+Capabilities.screenDPI+" DPI with touchscreen type "+Capabilities.touchscreenType + "\n"
				+"URL: " + FlexGlobals.topLevelApplication.url;
		}
	}
}
