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
	import com.flack.geni.display.areas.SliceArea;
	import com.flack.geni.display.windows.LoginWindow;
	import com.flack.geni.resources.DiskImageCollection;
	import com.flack.geni.resources.GeniUser;
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.resources.sites.GeniAuthorityCollection;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.sites.clearinghouses.ProtogeniClearinghouse;
	import com.flack.geni.resources.virt.SliceCollection;
	import com.flack.geni.tasks.groups.GetPublicResourcesTaskGroup;
	import com.flack.geni.tasks.groups.GetResourcesTaskGroup;
	import com.flack.geni.tasks.groups.GetUserTaskGroup;
	import com.flack.geni.tasks.groups.InitializeUserTaskGroup;
	import com.flack.geni.tasks.groups.slice.GetSlicesTaskGroup;
	import com.flack.shared.SharedMain;
	
	import mx.core.FlexGlobals;

	/**
	 * Holds all of the things we care about, GeniMain holds a globally static instance of this.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class GeniUniverse
	{
		public var managers:GeniManagerCollection;
		public function get user():GeniUser
		{
			return SharedMain.user as GeniUser;
		}
		public var authorities:GeniAuthorityCollection;
		public var clearinghouse:ProtogeniClearinghouse;
		
		public var userDiskImages:DiskImageCollection = new DiskImageCollection();
		
		public function GeniUniverse()
		{
			managers = new GeniManagerCollection();
			SharedMain.user = new GeniUser();
			authorities = new GeniAuthorityCollection();
			clearinghouse = new ProtogeniClearinghouse();
		}
		
		public function loadPublic():void
		{
			SharedMain.tasker.add(new GetPublicResourcesTaskGroup());
		}
		
		public function login():void
		{
			var loginWindow:LoginWindow = new LoginWindow();
			loginWindow.showWindow(true);
		}
		
		public function loadAuthenticated():void
		{
			// User is authenticated and either has a credential or an authority assigned to them
			if(user.CertificateSetUp)
			{
				// XXX other frameworks
				// Get user credential + keys if they have an authority
				if(user.authority == null || user.authority.type != GeniAuthority.TYPE_EMULAB)
					SharedMain.tasker.add(new InitializeUserTaskGroup(user, true));
				
				SharedMain.tasker.add(new GetResourcesTaskGroup(managers.length == 0));
				
				if(GeniMain.useSlice != null)
				{
					var sliceCollection:SliceCollection = new SliceCollection();
					sliceCollection.add(GeniMain.useSlice);
					SharedMain.tasker.add(new GetSlicesTaskGroup(sliceCollection, GeniMain.loadAllManagersWithoutAsking));
					var sliceArea:SliceArea = new SliceArea();
					FlexGlobals.topLevelApplication.viewContent(sliceArea);
					sliceArea.slice = GeniMain.useSlice;
				}
				else
				{
					SharedMain.tasker.add(
						new GetUserTaskGroup(
							user,
							GeniMain.geniUniverse.user.authority != null,
							true
						)
					);
				}
			}
			// Needs to authenticate
			else
				login();
		}
	}
}