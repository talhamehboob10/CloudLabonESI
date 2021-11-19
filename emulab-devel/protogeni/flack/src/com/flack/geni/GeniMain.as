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

package com.flack.geni
{
	import com.flack.geni.display.mapping.GeniMap;
	import com.flack.geni.display.mapping.GeniMapHandler;
	import com.flack.geni.display.mapping.mapproviders.esriprovider.EsriMap;
	import com.flack.geni.display.windows.StartWindow;
	import com.flack.geni.plugins.Plugin;
	import com.flack.geni.plugins.emulab.Emulab;
	import com.flack.geni.plugins.gemini.Gemini;
	import com.flack.geni.plugins.instools.Instools;
	import com.flack.geni.plugins.openflow.Openflow;
	import com.flack.geni.plugins.planetlab.Planetlab;
	import com.flack.geni.plugins.stitching.Stitching;
	import com.flack.geni.resources.sites.authorities.ProtogeniSliceAuthority;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.tasks.groups.GetCertBundlesTaskGroup;
	import com.flack.geni.tasks.http.PublicListAuthoritiesTask;
	import com.flack.shared.SharedMain;
	import com.flack.shared.display.areas.MapContent;
	import com.flack.shared.resources.docs.RspecVersion;
	import com.flack.shared.resources.docs.RspecVersionCollection;
	
	import mx.core.FlexGlobals;
	import mx.core.IVisualElement;
	
	/**
	 * Global container for things we use
	 * 
	 * @author mstrum
	 * 
	 */
	public class GeniMain
	{
		public static const becomeUserUrl:String = "http://www.protogeni.net/trac/protogeni/wiki/FlackManual#BecomingaUser";
		public static const manualUrl:String = "http://www.protogeni.net/trac/protogeni/wiki/FlackManual";
		public static const tutorialUrl:String = "http://www.protogeni.net/trac/protogeni/wiki/FlackTutorial";
		public static const tutorialLoginUrl:String = "http://www.protogeni.net/trac/protogeni/wiki/FlackManual#LoggingIn";
		public static const sshKeysSteps:String = "http://www.protogeni.net/trac/protogeni/wiki/Tutorial#UploadingSSHKeys";
		
		// Portal
		public static var skipStartup:Boolean = false;
		public static var keycertPreset:Boolean = false;
		public static var bundlePreset:Boolean = false;
		public static var loadAllManagersWithoutAsking:Boolean = false;
		public static var useSlice:Slice = null;
		public static var chUrl:String = "";
		
		// Tutorial
		public static var rspecListUrl:String = "";
		[Bindable]
		public static var viewList:Boolean = false;
		
		public static function preinitMode():void
		{
			GeniMain.geniUniverse = new GeniUniverse();
		}
		
		public static var mapper:GeniMapHandler;
		public static function initMode():void
		{
			var map:GeniMap = new EsriMap();
			var mapContent:MapContent = new MapContent();
			FlexGlobals.topLevelApplication.contentAreaGroup.Root = mapContent;
			mapContent.addElement(map as IVisualElement);
			
			mapper = new GeniMapHandler(map);
		}
		
		public static function initPlugins():void
		{
			plugins = new Vector.<Plugin>();
			plugins.push(new Gemini());
			plugins.push(new Stitching());
			//plugins.push(new Instools());
			plugins.push(new Emulab());
			plugins.push(new Planetlab());
			plugins.push(new Openflow());
			// Add new plugins
			for each(var plugin:Plugin in plugins)
				plugin.init();
		}
		
		public static function runFirst():void
		{
			if(geniUniverse.user.CertificateSetUp)
			{
				geniUniverse.loadAuthenticated();
			}
			else
			{
				// Initial tasks
				if(SharedMain.Bundle.length == 0 && !bundlePreset)
					SharedMain.tasker.add(new GetCertBundlesTaskGroup());
				if(GeniMain.geniUniverse.authorities.length == 0)
					SharedMain.tasker.add(new PublicListAuthoritiesTask());
				
				// Load initial window if needed
				if(geniUniverse.user.authority != null)
				{
					if(!geniUniverse.user.SslCertReady)
						GeniMain.geniUniverse.loadAuthenticated();
				}
				else
				{
					var startWindow:StartWindow = new StartWindow();
					startWindow.showWindow(true, true);
				}
			}
		}
		
		[Bindable]
		/**
		 * 
		 * @return GENI Universe containing everything GENI related
		 * 
		 */
		public static var geniUniverse:GeniUniverse;
		
		/**
		 * Plugins which are loaded
		 */
		public static var plugins:Vector.<Plugin>;
		
		/**
		 * RSPEC versions Flack knows how to parse or generate
		 */
		public static var usableRspecVersions:RspecVersionCollection = new RspecVersionCollection(
			[
				new RspecVersion(RspecVersion.TYPE_PROTOGENI, 0.1),
				new RspecVersion(RspecVersion.TYPE_PROTOGENI, 0.2),
				new RspecVersion(RspecVersion.TYPE_PROTOGENI, 2),
				new RspecVersion(RspecVersion.TYPE_GENI, 3)
			]
		);
		
		public static function get MapKey():String
		{
			try
			{
				if(FlexGlobals.topLevelApplication.parameters.mapkey != null)
					return FlexGlobals.topLevelApplication.parameters.mapkey;
			}
			catch(all:Error)
			{
			}
			return "";
		}
		
		public static function preloadParams():void
		{
			/*
			
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
			// External examples
			if(FlexGlobals.topLevelApplication.parameters.rspeclisturl != null)
			{
				rspecListUrl = FlexGlobals.topLevelApplication.parameters.rspeclisturl;
				viewList = true;
			}
			
			// Portal
			if(FlexGlobals.topLevelApplication.parameters.skipstartup != null)
			{
				skipStartup = FlexGlobals.topLevelApplication.parameters.skipstartup == "1";
			}
			if(FlexGlobals.topLevelApplication.parameters.bundlepreset != null)
			{
				bundlePreset = FlexGlobals.topLevelApplication.parameters.bundlepreset == "1";
			}
			if(FlexGlobals.topLevelApplication.parameters.keycertpreset != null)
			{
				geniUniverse.user.hasSetupSecurity = FlexGlobals.topLevelApplication.parameters.keycertpreset == "1";
			}
			if(FlexGlobals.topLevelApplication.parameters.keycert != null)
			{
				geniUniverse.user.sslCert = FlexGlobals.topLevelApplication.parameters.keycert;
				if(!geniUniverse.user.PrivateKeyEncrypted && bundlePreset) {
					geniUniverse.user.setSecurity(geniUniverse.user.sslCert);
				} else {
					if(FlexGlobals.topLevelApplication.parameters.keypassphrase != null) {
						geniUniverse.user.password = FlexGlobals.topLevelApplication.parameters.keypassphrase;
						if(bundlePreset)
							geniUniverse.user.setSecurity(geniUniverse.user.sslCert, geniUniverse.user.password);
					}
				}
			}
			if(FlexGlobals.topLevelApplication.parameters.loadallmanagerswithoutasking != null)
			{
				loadAllManagersWithoutAsking = FlexGlobals.topLevelApplication.parameters.loadallmanagerswithoutasking == "1";
			}
			if(FlexGlobals.topLevelApplication.parameters.saurl != null && FlexGlobals.topLevelApplication.parameters.saurn != null)
			{
				geniUniverse.user.authority = new ProtogeniSliceAuthority(
					FlexGlobals.topLevelApplication.parameters.saurn,
					FlexGlobals.topLevelApplication.parameters.saurl);
				geniUniverse.authorities.add(geniUniverse.user.authority);
			}
			if(FlexGlobals.topLevelApplication.parameters.churl != null)
			{
				chUrl = FlexGlobals.topLevelApplication.parameters.churl;
				geniUniverse.clearinghouse.url = chUrl;
			}
			if(FlexGlobals.topLevelApplication.parameters.sliceurn != null)
			{
				useSlice = new Slice(FlexGlobals.topLevelApplication.parameters.sliceurn);
				useSlice.authority = geniUniverse.user.authority;
				useSlice.creator = geniUniverse.user;
				geniUniverse.user.slices.add(useSlice);
			}
			
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
	}
}
