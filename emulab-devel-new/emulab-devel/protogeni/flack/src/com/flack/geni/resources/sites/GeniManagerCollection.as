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

package com.flack.geni.resources.sites
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.SliverTypeCollection;
	import com.flack.geni.resources.physical.PhysicalLink;
	import com.flack.geni.resources.physical.PhysicalLinkCollection;
	import com.flack.geni.resources.physical.PhysicalNode;
	import com.flack.geni.resources.physical.PhysicalNodeCollection;
	import com.flack.geni.resources.sites.managers.SupportedLinkType;
	import com.flack.geni.resources.sites.managers.SupportedLinkTypeCollection;
	import com.flack.geni.resources.sites.managers.SupportedSliverType;
	import com.flack.geni.resources.sites.managers.SupportedSliverTypeCollection;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.resources.sites.FlackManager;

	/**
	 * Collection of managers
	 * 
	 * @author mstrum
	 * 
	 */
	public final class GeniManagerCollection
	{
		public var collection:Vector.<GeniManager>;
		public function GeniManagerCollection()
		{
			collection = new Vector.<GeniManager>();
		}
		
		public function add(manager:GeniManager):void
		{
			collection.push(manager);
		}
		
		public function remove(manager:GeniManager):void
		{
			var idx:int = collection.indexOf(manager);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(manager:GeniManager):Boolean
		{
			return collection.indexOf(manager) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @return New instance of the same collection
		 * 
		 */
		public function get Clone():GeniManagerCollection
		{
			var clone:GeniManagerCollection = new GeniManagerCollection();
			for each(var manager:GeniManager in collection)
				clone.add(manager);
			return clone;
		}
		
		/**
		 * 
		 * @return Managers which have reported resources
		 * 
		 */
		public function get Valid():GeniManagerCollection
		{
			var validManagers:GeniManagerCollection = new GeniManagerCollection();
			for each(var manager:GeniManager in collection)
			{
				if(manager.Status == FlackManager.STATUS_VALID)
					validManagers.add(manager);
			}
			return validManagers;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @return Manager matching the ID
		 * 
		 */
		public function getById(id:String, log: Object = null):GeniManager
		{
			var idnUrn:IdnUrn = new IdnUrn(id);
			for each(var gm:GeniManager in collection)
			{
				if(gm.id.authority == idnUrn.authority)
					return gm;
			}
			return null;
		}
		
		public function getByStatus(status:int):GeniManagerCollection
		{
			var managers:GeniManagerCollection = new GeniManagerCollection();
			for each(var gm:GeniManager in collection)
			{
				if(gm.Status == status)
					managers.add(gm);
			}
			return managers;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @return Component matching the id
		 * 
		 */
		public function getComponentById(id:String):*
		{
			for each(var gm:GeniManager in collection)
			{
				var component:* = gm.getById(id);
				if(component != null)
					return component;
			}
			return null;
		}
		
		/**
		 * 
		 * @param hrn Human-readable name
		 * @return Manager matching the hrn
		 * 
		 */
		public function getByHrn(hrn:String):GeniManager
		{
			for each(var manager:GeniManager in collection)
			{
				if(manager.hrn == hrn)
					return manager;
			}
			return null;
		}
		
		public function getBySupportedSliverType(name:String):GeniManagerCollection
		{
			var managers:GeniManagerCollection = new GeniManagerCollection();
			for each(var manager:GeniManager in collection)
			{
				if(manager.supportedSliverTypes.getByName(name) != null)
					managers.add(manager);
			}
			return managers;
		}
		
		/**
		 * 
		 * @return All nodes
		 * 
		 */
		public function get Nodes():PhysicalNodeCollection
		{
			var results:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each(var manager:GeniManager in collection)
			{
				for each(var node:PhysicalNode in manager.nodes.collection)
					results.add(node);
			}
			return results; 
		}
		
		/**
		 * 
		 * @return All links
		 * 
		 */
		public function get Links():PhysicalLinkCollection
		{
			var results:PhysicalLinkCollection = new PhysicalLinkCollection();
			for each(var manager:GeniManager in collection)
			{
				for each(var link:PhysicalLink in manager.links.collection)
					results.add(link);
			}
			return results; 
		}
		
		/**
		 * 
		 * @return Maximum RSPEC supported by all of the managers
		 * 
		 */
		public function get MaximumRspecVersion():Number
		{
			var max:Number = GeniMain.usableRspecVersions.MaxVersion.version;
			for each(var manager:GeniManager in collection)
			{
				if(manager.inputRspecVersion.version < max)
					max = manager.inputRspecVersion.version;
			}
			return max; 
		}
		
		/**
		 * 
		 * @return List of link types which are usable within the given managers
		 * 
		 */
		public function get CommonLinkTypes():SupportedLinkTypeCollection
		{
			var supportedTypes:SupportedLinkTypeCollection = new SupportedLinkTypeCollection();
			var supportedType:SupportedLinkType = null;
			var i:int = 0;
			var manager:GeniManager = null;
			if(collection.length > 0)
			{
				var sourceManager:GeniManager = collection[0];
				for each(supportedType in sourceManager.supportedLinkTypes.collection)
				{
					var addType:SupportedLinkType = supportedType.Clone;
					if((supportedType.supportsManyManagers && length > 1) || (supportedType.supportsSameManager && length == 1))
					{
						for(i = 0; i < length; i++)
						{
							manager = collection[i];
							var testLinkType:SupportedLinkType = manager.supportedLinkTypes.getByName(supportedType.name);
							// Make sure the same type exists and it is still usable
							if(testLinkType == null ||
								(!testLinkType.supportsManyManagers && length > 1) ||
								(!testLinkType.supportsSameManager && length == 1))
							{
								addType = null;
								break;
							}
							else
							{
								// Settings can only be the least common denominator
								if(testLinkType.maxConnections < addType.maxConnections)
									addType.maxConnections = testLinkType.maxConnections;
								if(testLinkType.requiresIpAddresses && !addType.requiresIpAddresses)
									addType.requiresIpAddresses = true;
								if(testLinkType.level > addType.level)
									addType.level = testLinkType.level;
							}
						}
					}
					else
						addType = null;
					if(addType != null)
						supportedTypes.add(addType);
				}
			}
			
			return supportedTypes;
		}
		
		/**
		 * 
		 * @return List of sliver types available at all of the managers
		 * 
		 */
		public function get CommonSliverTypes():SupportedSliverTypeCollection
		{
			var supportedTypes:SupportedSliverTypeCollection = new SupportedSliverTypeCollection();
			if(collection.length > 0)
			{
				for each(var initialType:SupportedSliverType in collection[0].supportedSliverTypes.collection)
					supportedTypes.add(initialType);
			}
			for each(var manager:GeniManager in collection)
			{
				for(var i:int = 0; i < supportedTypes.length; i++)
				{
					var supportedType:SupportedSliverType = supportedTypes.collection[i];
					if(manager.supportedSliverTypes.getByName(supportedType.type.name) == null)
					{
						supportedTypes.remove(supportedType);
						i--;
					}
				}
			}
			return supportedTypes;
		}
		
		public function get SupportedSliverTypes():SupportedSliverTypeCollection
		{
			var supportedTypes:SupportedSliverTypeCollection = new SupportedSliverTypeCollection();
			for each(var manager:GeniManager in collection)
			{
				for each(var supportedType:SupportedSliverType in manager.supportedSliverTypes.collection)
				{
					if(supportedTypes.getByName(supportedType.type.name) == null)
						supportedTypes.add(supportedType);
				}
			}
			return supportedTypes;
		}
		
		public function get SharedVlans():Vector.<String>
		{
			var sharedVlans:Vector.<String> = new Vector.<String>();
			if(collection.length > 0)
			{
				for each(var initialSharedVlan:String in collection[0].sharedVlans)
					sharedVlans.push(initialSharedVlan);
			}
			for each(var manager:GeniManager in collection)
			{
				for(var i:int = 0; i < sharedVlans.length; i++)
				{
					var sharedVlan:String = sharedVlans[i];
					if(manager.sharedVlans != null && manager.sharedVlans.indexOf(sharedVlan) == -1)
					{
						sharedVlans.splice(i, 1);
						i--;
					}
				}
			}
			return sharedVlans;
		}
		
		public function forceApiType(type:int = ApiDetails.API_GENIAM):void
		{
			for each(var manager:GeniManager in collection)
			{
				manager.setApi(new ApiDetails(type));
			}
		}
	}
}