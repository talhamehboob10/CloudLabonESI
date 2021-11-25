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
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.resources.sites.GeniAuthorityCollection;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.sites.authorities.ProtogeniSliceAuthority;
	import com.flack.shared.SharedCache;
	import com.flack.shared.SharedMain;
	
	import flash.utils.Dictionary;

	/**
	 * Handles saving and loading data from a cache kept on the client computer.
	 * 
	 * OSes other than Windows can have issues...
	 * 
	 * @author mstrum
	 * 
	 */
	public final class GeniCache
	{
		private static var ignoreUpdate:Boolean = false;
		
		public function GeniCache()
		{
		}
		
		/*
		public static function initialize():void
		{
		SharedMain.geniDispatcher.addEventListener(FlackEvent.CHANGED_AUTHORITIES, updateAuthorties);
		SharedMain.geniDispatcher.addEventListener(FlackEvent.CHANGED_MANAGERS, updateManagers);
		}
		
		// Update with live data
		public static function updateAuthorties(event:FlackEvent):void
		{
			if(ignoreUpdate)
			{
				ignoreUpdate = false;
				return;
			}
			if(SharedCache._sharedObject == null || !SharedCache.UsableCache() || event.action != FlackEvent.ACTION_POPULATED)
				return;
			
			SharedCache._sharedObject.data.authoritiesCreated = new Date();
			SharedCache._sharedObject.data.authorities = [];
			for each(var authority:GeniAuthority in GeniMain.geniUniverse.authorities.collection)
			{
				SharedCache._sharedObject.data.authorities.push(
					{
						id:authority.id.full,
						url:authority.url,
						workingCertGet:authority.workingCertGet
					}
				);
			}
		}
		
		public static function updateManagers(event:FlackEvent):void
		{
			if(ignoreUpdate)
			{
				ignoreUpdate = false;
				return;
			}
			if(SharedCache._sharedObject == null || !SharedCache.UsableCache() || event.action != FlackEvent.ACTION_POPULATED)
				return;
			
			SharedCache._sharedObject.data.managersCreated = new Date();
			SharedCache._sharedObject.data.managers = [];
			for each(var manager:GeniManager in GeniMain.geniUniverse.managers.collection)
			{
				SharedCache._sharedObject.data.managers.push(
					{
						id:manager.id.full,
						url:manager.url,
						hrn:manager.hrn,
						type:manager.type,
						api:manager.api
					}
				);
			}
		}
		*/
		
		// Managers to list
		public static function shouldAskWhichManagersToWatch():Boolean
		{
			if(SharedCache._sharedObject == null || SharedCache._sharedObject.data.ask_which_managers_to_watch == null)
				return true;
			
			// If list of managers is different than list stored, ask
			var managersToWatch:Dictionary = GeniCache.getManagersToWatch();
			for each(var manager:GeniManager in GeniMain.geniUniverse.managers.collection)
			{
				if(managersToWatch[manager.id.full] == null)
					return true;
			}
			
			return SharedCache._sharedObject.data.ask_which_managers_to_watch;
		}
		
		public static function setAskWhichManagersToWatch(value:Boolean):void
		{
			if(SharedCache._sharedObject == null)
				return;
			
			SharedCache._sharedObject.data.ask_which_managers_to_watch = value;
		}
		
		public static function setManagersToWatch(managersToWatch:Dictionary):void
		{
			if(SharedCache._sharedObject == null)
				return;
			
			SharedCache._sharedObject.data.managers_to_watch = [];
			for(var managerId:String in managersToWatch)
				SharedCache._sharedObject.data.managers_to_watch.push({id:managerId, watch:managersToWatch[managerId]});
		}
		
		public static function getManagersToWatch():Dictionary
		{
			var results:Dictionary = new Dictionary();
			
			if(SharedCache._sharedObject != null && SharedCache._sharedObject.data.managers_to_watch != null)
			{
				for each(var managerWatchObject:Object in SharedCache._sharedObject.data.managers_to_watch)
					results[managerWatchObject.id] = managerWatchObject.watch;
			}
			
			return results;
		}
		
		public static function clearManagersToWatch():void
		{
			if(SharedCache._sharedObject != null)
			{
				delete SharedCache._sharedObject.data.managers_to_watch;
				delete SharedCache._sharedObject.data.ask_which_managers_to_watch;
			}
		}
		
		public static function getForceAmApi():Boolean
		{
			var forceAmApi:Boolean = false;
			
			if(SharedCache._sharedObject != null && SharedCache._sharedObject.data.force_am_api != null)
			{
				forceAmApi = SharedCache._sharedObject.data.force_am_api;
			}
			
			return forceAmApi;
		}
		
		public static function setForceAmApi(value:Boolean):void
		{
			if(SharedCache._sharedObject != null)
			{
				SharedCache._sharedObject.data.force_am_api = value;
			}
		}
		
		// Manual authorities
		public static function wasAuthorityManuallyAdded(authority:GeniAuthority):Boolean
		{
			if(SharedCache._sharedObject == null || SharedCache._sharedObject.data.manual_authorities == null)
				return false;
			for each(var authorityObject:Object in SharedCache._sharedObject.data.manual_authorities)
			{
				if(authorityObject.id == authority.id.full)
					return true;
			}
			return false;
		}
		
		public static function removeManuallyAddedAuthority(authority:GeniAuthority):void
		{
			if(SharedCache._sharedObject == null || SharedCache._sharedObject.data.manual_authorities == null)
				return;
			for(var i:int = 0; i < SharedCache._sharedObject.data.manual_authorities.length; i++)
			{
				if(SharedCache._sharedObject.data.manual_authorities[i].id == authority.id.full)
				{
					SharedCache._sharedObject.data.manual_authorities.splice(i, 1);
					return;
				}
			}
			return;
		}
		
		public static function addAuthorityManually(authority:ProtogeniSliceAuthority, authorityCert:String):void
		{
			if(SharedCache._sharedObject == null || !SharedCache.UsableCache())
				return;
			
			if(SharedCache._sharedObject.data.manual_authorities == null)
				SharedCache._sharedObject.data.manual_authorities = [];
			
			SharedCache._sharedObject.data.manual_authorities.push(
				{
					id:authority.id.full,
					url:authority.url,
					working_cert_get:authority.workingCertGet,
					cert:authorityCert
				}
			);
		}
		
		public static function getManualAuthorities():GeniAuthorityCollection
		{
			var results:GeniAuthorityCollection = new GeniAuthorityCollection();
			
			if(SharedCache._sharedObject != null && SharedCache._sharedObject.data.manual_authorities != null)
			{
				var authorityCerts:String = "";
				for each(var authorityObject:Object in SharedCache._sharedObject.data.manual_authorities)
				{
					// Skip older cached managers.
					var newAuthority:ProtogeniSliceAuthority = new ProtogeniSliceAuthority(
						authorityObject.id,
						authorityObject.url,
						authorityObject.working_cert_get);
					var newCert:String = authorityObject.cert;
					if(newCert.length > 0 && SharedMain.Bundle.indexOf(newCert) == -1)
						authorityCerts += newCert;
					results.add(newAuthority);
				}
				if(authorityCerts.length > 0)
					SharedMain.Bundle += authorityCerts;
			}
			return results;
		}
		
		public static function clearManualAuthorities():void
		{
			if(SharedCache._sharedObject != null)
			{
				delete SharedCache._sharedObject.data.manual_authorities;
			}
		}
		
		// Manual managers
		public static function wasManagerManuallyAdded(manager:GeniManager):Boolean
		{
			if(SharedCache._sharedObject == null || SharedCache._sharedObject.data.manual_managers == null)
				return false;
			for each(var managerObject:Object in SharedCache._sharedObject.data.manual_managers)
			{
				if(managerObject.id == manager.id.full)
					return true;
			}
			return false;
		}
		
		public static function removeManuallyAddedManager(manager:GeniManager):void
		{
			if(SharedCache._sharedObject == null || SharedCache._sharedObject.data.manual_managers == null)
				return;
			for(var i:int = 0; i < SharedCache._sharedObject.data.manual_managers.length; i++)
			{
				if(SharedCache._sharedObject.data.manual_managers[i].id == manager.id.full)
				{
					SharedCache._sharedObject.data.manual_managers.splice(i, 1);
					return;
				}
			}
			return;
		}
		
		public static function addManagerManually(manager:GeniManager, managerCert:String):void
		{
			if(SharedCache._sharedObject == null || !SharedCache.UsableCache())
				return;
			
			if(SharedCache._sharedObject.data.manual_managers == null)
				SharedCache._sharedObject.data.manual_managers = [];
			
			SharedCache._sharedObject.data.manual_managers.push(
				{
					id:manager.id.full,
					url:manager.url,
					hrn:manager.hrn,
					type:manager.type,
					api_type:manager.api.type,
					cert:managerCert
				}
			);
		}
		
		public static function getManualManagers():GeniManagerCollection
		{
			var results:GeniManagerCollection = new GeniManagerCollection();
			
			if(SharedCache._sharedObject != null && SharedCache._sharedObject.data.manual_managers != null)
			{
				var managerCerts:String = "";
				for each(var managerObject:Object in SharedCache._sharedObject.data.manual_managers)
				{
					// Skip older cached managers.
					if(managerObject.api_type == null)
						continue;
					
					var newManager:GeniManager = new GeniManager(managerObject.type, managerObject.api_type , managerObject.id);
					newManager.url = managerObject.url;
					newManager.api.url = newManager.url;
					newManager.hrn = managerObject.hrn;
					var newCert:String = managerObject.cert;
					if(newCert.length > 0 && SharedMain.Bundle.indexOf(newCert) == -1)
						managerCerts += newCert;
					results.add(newManager);
				}
				if(managerCerts.length > 0)
					SharedMain.Bundle += managerCerts;
			}
			return results;
		}
		
		public static function clearManualManagers():void
		{
			if(SharedCache._sharedObject != null)
			{
				delete SharedCache._sharedObject.data.manual_managers;
			}
		}
	}
}