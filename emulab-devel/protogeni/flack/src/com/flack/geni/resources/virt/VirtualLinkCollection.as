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

package com.flack.geni.resources.virt
{
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;

	/**
	 * Collection of virtual links
	 * 
	 * @author mstrum
	 * 
	 */
	public final class VirtualLinkCollection extends VirtualComponentCollection
	{
		public function VirtualLinkCollection(src:Array = null)
		{
			super(src);
		}
		
		/**
		 * 
		 * @param o Object wanting to use ID
		 * @param id Desired new client ID
		 * @return TRUE if the given object can use the client ID
		 * 
		 */
		public function isIdUnique(o:*, id:String):Boolean
		{
			var found:Boolean = false;
			for each(var testLink:VirtualLink in collection)
			{
				if(o == testLink)
					continue;
				if(testLink.clientId == id)
					return false;
			}
			return true;
		}
		
		public function getLinkByClientId(id:String):VirtualLink
		{
			return super.getByClientId(id) as VirtualLink;
		}
		
		/**
		 * 
		 * @param manager Manager
		 * @return Links connected to the given manager
		 * 
		 */
		public function getConnectedToManager(manager:GeniManager):VirtualLinkCollection
		{
			var connectedLinks:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var link:VirtualLink in collection)
			{
				if((link.managerRefs.Managers.contains(manager) || link.interfaceRefs.Interfaces.Managers.contains(manager)) && !connectedLinks.contains(link))
					connectedLinks.add(link);
			}
			return connectedLinks;
		}
		
		public function getConnectedToMultipleManagers():VirtualLinkCollection
		{
			var connectedLinks:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var link:VirtualLink in collection)
			{
				if(link.interfaceRefs.Interfaces.Managers.length > 1 || link.managerRefs.length > 1)
					connectedLinks.add(link);
			}
			return connectedLinks;
		}
		
		/**
		 * 
		 * @param managers Managers
		 * @return Links connected to the given managers
		 * 
		 */
		public function getConnectedToManagers(managers:GeniManagerCollection):VirtualLinkCollection
		{
			var connectedLinks:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var link:VirtualLink in collection)
			{
				var linkManagers:GeniManagerCollection = link.interfaceRefs.Interfaces.Managers;
				for each(var refManager:GeniManagerReference in link.managerRefs.collection)
				{
					if(!linkManagers.contains(refManager.referencedManager))
						linkManagers.add(refManager.referencedManager);
				}
				var valid:Boolean = true;
				for each(var linkedManager:GeniManager in linkManagers.collection)
				{
					if(!managers.contains(linkedManager))
					{
						valid = false;
						break;
					}
				}
				if(!valid)
					break;
				if(!connectedLinks.contains(link))
					connectedLinks.add(link);
			}
			return connectedLinks;
		}
		
		/**
		 * 
		 * @param nodes Virtual nodes
		 * @return Links connected to the given nodes
		 * 
		 */
		public function getConnectedToNodes(nodes:VirtualNodeCollection):VirtualLinkCollection
		{
			var connectedLinks:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var link:VirtualLink in collection)
			{
				var linkNodes:VirtualNodeCollection = link.interfaceRefs.Interfaces.Nodes;
				if(linkNodes.length == nodes.length)
				{
					var found:Boolean = true;
					for each(var linkNode:VirtualNode in linkNodes.collection)
					{
						if(!nodes.contains(linkNode))
							found = false;
					}
					if(found)
						connectedLinks.add(link);
				}
			}
			return connectedLinks;
		}
		
		/**
		 * 
		 * @param node Virtual node
		 * @return Links connected to the given node
		 * 
		 */
		public function getConnectedToNode(node:VirtualNode):VirtualLinkCollection
		{
			var connectedLinks:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var link:VirtualLink in collection)
			{
				if(link.interfaceRefs.Interfaces.Nodes.contains(node))
					connectedLinks.add(link);
			}
			return connectedLinks;
		}
		
		/**
		 * 
		 * @param type Link type
		 * @return Links of the given type
		 * 
		 */
		public function getByType(type:String):VirtualLinkCollection
		{
			var group:VirtualLinkCollection = new VirtualLinkCollection();
			for each (var l:VirtualLink in collection)
			{
				if(l.type.name == type)
					group.add(l);
			}
			return group;
		}
		
		public function get Stitched():VirtualLinkCollection
		{
			var group:VirtualLinkCollection = new VirtualLinkCollection();
			for each (var l:VirtualLink in collection)
			{
				if(l.interfaceRefs.Interfaces.Managers.length > 0
					&& l.sharedVlanName.length == 0
					&& l.type.name.length == 0)
				{
					group.add(l);
				}
			}
			return group;
		}
		
		/**
		 * 
		 * @return Interfaces used in the links
		 * 
		 */
		public function get Interfaces():VirtualInterfaceCollection
		{
			var interfaces:VirtualInterfaceCollection = new VirtualInterfaceCollection();
			for each(var link:VirtualLink in collection)
			{
				for each(var linkInterface:VirtualInterface in link.interfaceRefs.Interfaces.collection)
				{
					if(!interfaces.contains(linkInterface))
						interfaces.add(linkInterface);
				}
			}
			return interfaces;
		}
		
		/**
		 * 
		 * @return Maximum capacity found in any one path
		 * 
		 */
		public function get MaximumCapacity():Number
		{
			var max:Number = 0;
			for each(var link:VirtualLink in collection)
			{
				var linkCapacity:Number = link.Capacity;
				if(linkCapacity > max)
					max = linkCapacity;
			}
			return max;
		}
		
		/**
		 * 
		 * @return Types of links
		 * 
		 */
		public function get Types():Vector.<String>
		{
			var types:Vector.<String> = new Vector.<String>();
			for each(var link:VirtualLink in collection)
			{
				if(types.indexOf(link.type.name) == -1)
					types.push(link.type.name);
			}
			return types.sort(
				function compareTypes(a:String, b:String):Number
				{
					if(a < b)
						return -1;
					else if(a == b)
						return 0;
					else
						return 1;
				});
		}
	}
}