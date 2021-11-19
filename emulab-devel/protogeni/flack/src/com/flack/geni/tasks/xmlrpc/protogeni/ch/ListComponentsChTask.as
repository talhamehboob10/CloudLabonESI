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

package com.flack.geni.tasks.xmlrpc.protogeni.ch
{
	import com.flack.geni.GeniCache;
	import com.flack.geni.GeniMain;
	import com.flack.geni.plugins.emulab.DelaySliverType;
	import com.flack.geni.plugins.emulab.EmulabBbgSliverType;
	import com.flack.geni.plugins.emulab.EmulabSppSliverType;
	import com.flack.geni.plugins.emulab.FirewallSliverType;
	import com.flack.geni.plugins.planetlab.PlanetlabSliverType;
	import com.flack.geni.resources.GeniUser;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.LinkType;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Gets the list and information for the component managers listed at a clearinghouse
	 * 
	 * @author mstrum
	 * 
	 */
	public class ListComponentsChTask extends ProtogeniXmlrpcTask
	{
		public var user:GeniUser;
		
		/**
		 * 
		 * @param newUser User making the call, needed for this call
		 * 
		 */
		public function ListComponentsChTask(newUser:GeniUser)
		{
			super(
				GeniMain.geniUniverse.clearinghouse.url,
				ProtogeniXmlrpcTask.MODULE_CH,
				ProtogeniXmlrpcTask.METHOD_LISTCOMPONENTS,
				"List managers",
				"Gets the list and information for the component managers listed at a clearinghouse"
			);
			user = newUser;
		}
		
		override protected function createFields():void
		{
			addNamedField("credential", user.credential.Raw);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				GeniMain.geniUniverse.managers = new GeniManagerCollection();
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_MANAGERS,
					null,
					FlackEvent.ACTION_REMOVED
				);
				
				for each(var obj:Object in data)
				{
					try
					{
						var url:String = obj.url;
						var foamPattern : RegExp = /\Wfoam\W/;
						if (foamPattern.test(url)) {
							continue;
						}
						var hostPattern:RegExp = /^(http(s?):\/\/([^\/]+))(\/.*)?$/;
						var match : Object = hostPattern.exec(url);
						if(match != null && match[4] == null) {
							url = StringUtil.makeSureEndsWith(url, "/"); // needs this for forge...
						}
						var newId:IdnUrn = new IdnUrn(obj.urn);
						var newManager:GeniManager = new GeniManager(GeniManager.TYPE_UNKNOWN, ApiDetails.API_GENIAM, newId.full, obj.hrn);
						
						// ProtoGENI Component Manager
						if(newId.name.toLowerCase() == "cm")
						{
							newManager.type = GeniManager.TYPE_PROTOGENI;
							if(url.indexOf("/am") != -1) {
								newManager.api.type = ApiDetails.API_GENIAM;
							} else {
								newManager.api.type = ApiDetails.API_PROTOGENI;
							}
							newManager.url = url.substr(0, url.length-3);
							
							newManager.supportedLinkTypes.getOrCreateByName(LinkType.GRETUNNEL_V2);
							newManager.supportedLinkTypes.getOrCreateByName(LinkType.EGRE);
							newManager.supportedLinkTypes.getOrCreateByName(LinkType.LAN_V2);
							newManager.supportedLinkTypes.getOrCreateByName(LinkType.STITCHED);
							
							if(newManager.hrn == "shadowgeni.cm")
							{
								newManager.supportedLinkTypes.getByName(LinkType.LAN_V2).requiresIpAddresses = true;
							}
							
							// Link Types (not advertised...)
							if(newManager.hrn == "ukgeni.cm"
								|| newManager.hrn == "utahemulab.cm")
							{
								newManager.supportedLinkTypes.getOrCreateByName(LinkType.ION);
							}
							if(newManager.hrn == "wail.cm"
								|| newManager.hrn == "utahemulab.cm")
							{
								newManager.supportedLinkTypes.getOrCreateByName(LinkType.GPENI);
							}
							if(newManager.hrn == "ukgeni.cm"
								|| newManager.hrn == "utahemulab.cm"
								|| newManager.hrn == "wail.cm"
								|| newManager.hrn == "shadowgeni.cm")
							{
								newManager.supportedLinkTypes.getOrCreateByName(LinkType.VLAN);
							}
							
							// Node Types (not advertised yet...)
							if(newManager.hrn == "utahemulab.cm")
							{
								newManager.supportedSliverTypes.getOrCreateByName(FirewallSliverType.TYPE_FIREWALL);
								newManager.supportedSliverTypes.getOrCreateByName(EmulabSppSliverType.TYPE_EMULAB_SPP);
							}
							if(newManager.hrn == "utahemulab.cm"
								|| newManager.hrn == "ukgeni.cm"
								|| newManager.hrn == "jonlab.cm")
							{
								newManager.supportedSliverTypes.getOrCreateByName(DelaySliverType.TYPE_DELAY);
							}
							
							if(newManager.hrn == "utahemulab.cm"
								|| newManager.hrn == "ukgeni.cm"
								|| newManager.hrn == "wail.cm")
							{
								newManager.supportedSliverTypes.getOrCreateByName(EmulabBbgSliverType.TYPE_EMULAB_BBG);
							}
						}
						else if(newId.name.toLowerCase() == ProtogeniXmlrpcTask.MODULE_SA)
						{
							newManager.type = GeniManager.TYPE_SFA;
							newManager.api.type = ApiDetails.API_GENIAM;
							newManager.url = url;
							
							if(newManager.hrn != "genicloud.hplabs.sa")
							{
								newManager.supportedLinkTypes.getOrCreateByName(LinkType.GRETUNNEL_V2);
								newManager.supportedLinkTypes.getOrCreateByName(LinkType.STITCHED);
							}
							
							newManager.supportedSliverTypes.getOrCreateByName(PlanetlabSliverType.TYPE_PLANETLAB_V2);
						}
						else
						{
							newManager.url = url;
							if (newManager.hrn == "exogeni.net.am"
								|| newManager.hrn == "exogeni.net.bbnvmsite.am"
								|| newManager.hrn == "exogeni.net.fiuvmsite.am"
								|| newManager.hrn == "exogeni.net.rcivmsite.am"
								|| newManager.hrn == "exogeni.net.uhvmsite.am")
							{
								newManager.supportedLinkTypes.getOrCreateByName(LinkType.LAN_V2);
							}
							
							newManager.supportedLinkTypes.getOrCreateByName(LinkType.STITCHED);
						}
						newManager.api.url = newManager.url;
						
						GeniMain.geniUniverse.managers.add(newManager);
						
						relatedTo.push(newManager);
						
						addMessage(
							"Added manager",
							newManager.toString(),
							LogMessage.LEVEL_INFO,
							LogMessage.IMPORTANCE_HIGH
						);
						
						SharedMain.sharedDispatcher.dispatchChanged(
							FlackEvent.CHANGED_MANAGER,
							newManager,
							FlackEvent.ACTION_CREATED
						);
						
					}
					catch(e:Error)
					{
						addMessage(
							"Error adding",
							"Couldn't add manager from list:\n" + obj.toString(),
							LogMessage.LEVEL_WARNING,
							LogMessage.IMPORTANCE_HIGH
						);
					}
				}
				
				addMessage(
					"Added " + GeniMain.geniUniverse.managers.length + " manager(s)",
					"Added " + GeniMain.geniUniverse.managers.length + " manager(s)",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				var manuallyAddedManagers:GeniManagerCollection = GeniCache.getManualManagers();
				for each(var cachedManager:GeniManager in manuallyAddedManagers.collection)
				{
					if(GeniMain.geniUniverse.managers.getById(cachedManager.id.full) == null)
					{
						GeniMain.geniUniverse.managers.add(cachedManager);
						
						addMessage(
							"Added cached manager",
							cachedManager.toString(),
							LogMessage.LEVEL_INFO,
							LogMessage.IMPORTANCE_HIGH
						);
						
						SharedMain.sharedDispatcher.dispatchChanged(
							FlackEvent.CHANGED_MANAGER,
							cachedManager,
							FlackEvent.ACTION_CREATED
						);
					}
				}
				
				if(GeniCache.getForceAmApi())
					GeniMain.geniUniverse.managers.forceApiType(ApiDetails.API_GENIAM);
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_MANAGERS,
					null,
					FlackEvent.ACTION_POPULATED
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}
