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

package com.flack.emulab
{
	import com.flack.emulab.display.areas.WelcomeArea;
	import com.flack.emulab.resources.EmulabUser;
	import com.flack.emulab.resources.sites.EmulabManager;
	import com.flack.emulab.tasks.groups.GetUserTaskGroup;
	import com.flack.emulab.tasks.http.GetUserCertTask;
	import com.flack.emulab.tasks.xmlrpc.node.EmulabNodeGetListTask;
	import com.flack.emulab.tasks.xmlrpc.osid.EmulabOsidGetListTask;
	import com.flack.geni.tasks.groups.GetCertBundlesTaskGroup;
	import com.flack.shared.SharedMain;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.utils.NetUtil;
	
	import mx.core.FlexGlobals;


	/**
	 * Global container for things we use
	 * 
	 * @author mstrum
	 * 
	 */
	public class EmulabMain
	{
		public static var URL_NSCOMMANDS:String = "http://users.emulab.net/trac/emulab/wiki/nscommands";
		
		public static var manager:EmulabManager;
		public static function get user():EmulabUser
		{
			return SharedMain.user as EmulabUser;
		}
		
		public static function preinitMode():void
		{
			SharedMain.user = new EmulabUser();
		}
		
		public static function initMode():void
		{
			FlexGlobals.topLevelApplication.contentAreaGroup.Root = new WelcomeArea();
			
			var managerUrl:String;
			if(FlexGlobals.topLevelApplication.url.indexOf("file:") == -1)
				managerUrl = NetUtil.tryGetBaseUrl(FlexGlobals.topLevelApplication.url);
			else
				managerUrl = "https://www.emulab.net";
			manager = new EmulabManager("");
			manager.url = managerUrl;
			manager.api = new ApiDetails(ApiDetails.API_EMULAB, 0.1, managerUrl + ":3069/usr/testbed");
			
			if(SharedMain.Bundle.length == 0)
				SharedMain.tasker.add(new GetCertBundlesTaskGroup());
			SharedMain.tasker.add(new GetUserCertTask());
			
			SharedMain.tasker.add(new EmulabNodeGetListTask());
			SharedMain.tasker.add(new EmulabOsidGetListTask());
			
			SharedMain.tasker.add(new GetUserTaskGroup());
		}
		
		public static function preloadParams():void
		{
			/*
			try{
			if(FlexGlobals.topLevelApplication.parameters.mapkey != null)
			{
			Main.Application().forceMapKey = FlexGlobals.topLevelApplication.parameters.mapkey;
			}
			} catch(all:Error) {
			}
			
			try{
			if(FlexGlobals.topLevelApplication.parameters.debug != null)
			{
			Main.debugMode = FlexGlobals.topLevelApplication.parameters.debug == "1";
			}
			} catch(all:Error) {
			}
			
			try{
			if(FlexGlobals.topLevelApplication.parameters.pgonly != null)
			{
			Main.protogeniOnly = FlexGlobals.topLevelApplication.parameters.pgonly == "1";
			}
			} catch(all:Error) {
			}
			*/
		}
		
		public static function loadParams():void
		{
			/*
			try{
			if(FlexGlobals.topLevelApplication.parameters.mode != null)
			{
			var input:String = FlexGlobals.topLevelApplication.parameters.mode;
			
			Main.Application().allowAuthenticate = input != "publiconly";
			Main.geniHandler.unauthenticatedMode = input != "authenticate";
			}
			} catch(all:Error) {
			}
			try{
			if(FlexGlobals.topLevelApplication.parameters.saurl != null)
			{
			for each(var sa:ProtogeniSliceAuthority in Main.geniHandler.GeniAuthorities.source) {
			if(sa.Url == FlexGlobals.topLevelApplication.parameters.saurl) {
			Main.geniHandler.forceAuthority = sa;
			break;
			}
			}
			}
			} catch(all:Error) {
			}
			try{
			if(FlexGlobals.topLevelApplication.parameters.publicurl != null)
			{
			Main.geniHandler.publicUrl = FlexGlobals.topLevelApplication.parameters.publicurl;
			}
			} catch(all:Error) {
			}
			*/
		}
		
		public static function initPlugins():void
		{
		}
		
		public static function runFirst():void
		{
			
		}
	}
}
