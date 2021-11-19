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

package com.flack.geni.resources.physical
{
	import com.flack.geni.resources.SliverType;
	import com.flack.geni.resources.SliverTypeCollection;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	
	import flash.utils.Dictionary;

	public class PhysicalNodeCollection
	{
		public var collection:Vector.<PhysicalNode>;
		public function PhysicalNodeCollection()
		{
			collection = new Vector.<PhysicalNode>();
		}
		
		public function add(node:PhysicalNode):void
		{
			collection.push(node);
		}
		
		public function remove(node:PhysicalNode):void
		{
			var idx:int = collection.indexOf(node);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(node:PhysicalNode):Boolean
		{
			return collection.indexOf(node) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param id ID of the node to find
		 * @return Node with the given ID
		 * 
		 */
		public function getById(id:String):PhysicalNode
		{
			for each (var n:PhysicalNode in collection)
			{
				if(n.id.full == id)
					return n;
			}
			return null;
		}
		
		/**
		 * 
		 * @param name Name of the node to find
		 * @return Node with the given name
		 * 
		 */
		public function getByName(name:String):PhysicalNode
		{
			for each (var n:PhysicalNode in collection)
			{
				if(n.name == name)
					return n;
			}
			return null;
		}
		
		/**
		 * 
		 * @param name Partial name to search for
		 * @return All nodes with names which include 'name' in them
		 * 
		 */
		public function searchByName(name:String):PhysicalNodeCollection
		{
			var nodes:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.name.indexOf(name) != -1)
					nodes.add(n);
			}
			return nodes;
		}
		
		/**
		 * 
		 * @param type Hardware type name we are looking for
		 * @return Nodes of the given hardware type
		 * 
		 */
		public function getByHardwareType(type:String):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.hardwareTypes.getByName(type) != null)
					group.add(n);
			}
			return group;
		}
		
		public function getBySliverType(type:String):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.sliverTypes.getByName(type) != null)
					group.add(n);
			}
			return group;
		}
		
		/**
		 * Returns group of slicable or non-slicable nodes.
		 * 
		 * @param slicable True if the returned nodes should have sliver types
		 * @return List of slicable or non-slicable nodes
		 * 
		 */
		public function getBySlicable(slicable:Boolean):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if((slicable && n.sliverTypes.length > 0) ||
					(!slicable && n.sliverTypes.length == 0))
				{
					group.add(n);
				}
			}
			return group;
		}
		
		/**
		 * 
		 * @param available Should the nodes be available?
		 * @return Nodes with the same availability given
		 * 
		 */
		public function getByAvailability(available:Boolean):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.available == available)
					group.add(n);
			}
			return group;
		}
		
		/**
		 * 
		 * @param exclusive Should the nodes be exclusive?
		 * @return Nodes with the same exclusivity given
		 * 
		 */
		public function getByExclusivity(exclusive:Boolean):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.exclusive == exclusive)
					group.add(n);
			}
			return group;
		}
		
		/**
		 * 
		 * @param manager Manager we want nodes for
		 * @return Nodes from the given manager
		 * 
		 */
		public function getByManager(manager:GeniManager):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.manager == manager)
					group.add(n);
			}
			return group;
		}
		
		/**
		 * 
		 * @param managers Managers we are looking for
		 * @return Nodes from the given managers
		 * 
		 */
		public function getByManagers(managers:GeniManagerCollection):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(managers.contains(n.manager as GeniManager))
					group.add(n);
			}
			return group;
		}
		
		/**
		 * 
		 * @param id ID of the interface we are looking for
		 * @return Node interface with the given ID
		 * 
		 */
		public function getInterfaceById(id:String):PhysicalInterface
		{
			for each(var node:PhysicalNode in collection)
			{
				var ni:PhysicalInterface = node.interfaces.getById(id);
				if(ni != null)
					return ni;
			}
			return null;
		}
		
		/**
		 * 
		 * @param capacity Minimum capacity (kbs) nodes should have for links
		 * @return Nodes with at least the given capacity
		 * 
		 */
		public function getByMinimumCapacity(capacity:Number):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.Links.MaximumCapacity >= capacity)
					group.add(n);
			}
			return group;
		}
		
		/**
		 * 
		 * @param speed Minimum CPU speed
		 * @return Nodes with at least the CPU speed given
		 * 
		 */
		public function getByMinimumCpuSpeed(speed:int):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.cpuSpeed >= speed)
					group.add(n);
			}
			return group;
		}
		
		/**
		 * 
		 * @param size Minimum RAM size
		 * @return Nodes with at least the given amount of RAM
		 * 
		 */
		public function getByMinimumRamSize(size:int):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.ramSize >= size)
					group.add(n);
			}
			return group;
		}
		
		/**
		 * 
		 * @param name Partial name
		 * @param availableOnly Availability
		 * @param type Hardware type
		 * @return Nodes matching the given criteria
		 * 
		 */
		public function search(name:String, availableOnly:Boolean = false, type:String = ""):PhysicalNodeCollection
		{
			var results:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each(var node:PhysicalNode in collection)
			{
				if(node.search(name, availableOnly, type))
					results.add(node);
			}
			return results;
		}
		
		/**
		 * 
		 * @param otherCollection Collection we want to know if it is the same as this
		 * @return TRUE if the given collection is the same as this
		 * 
		 */
		public function sameAs(otherCollection:PhysicalNodeCollection):Boolean
		{
			if(otherCollection.length != length)
				return false;
			for each(var node:PhysicalNode in collection)
			{
				if(!otherCollection.contains(node))
					return false;
			}
			return true;
		}
		
		/**
		 * 
		 * @return All available nodes
		 * 
		 */
		public function get Available():PhysicalNodeCollection
		{
			return getByAvailability(true);
		}
		
		/**
		 * 
		 * @return All exclusive nodes
		 * 
		 */
		public function get Exclusive():PhysicalNodeCollection
		{
			return getByExclusivity(true);
		}
		
		/**
		 * 
		 * @return All slicable nodes
		 * 
		 */
		public function get Slicable():PhysicalNodeCollection
		{
			return getBySlicable(true);
		}
		
		/**
		 * 
		 * @return All shared nodes
		 * 
		 */
		public function get Shared():PhysicalNodeCollection
		{
			return getByExclusivity(false);
		}
		
		/**
		 * 
		 * @return New instance of this collection
		 * 
		 */
		public function get Clone():PhysicalNodeCollection
		{
			var clone:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each(var node:PhysicalNode in collection)
				clone.add(node);
			return clone;
		}
		
		/**
		 * 
		 * @return All locations of nodes
		 * 
		 */
		public function get Locations():PhysicalLocationCollection
		{
			var locations:PhysicalLocationCollection = new PhysicalLocationCollection();
			for each(var node:PhysicalNode in collection)
			{
				if(!locations.contains(node.location))
					locations.add(node.location);
			}
			return locations;
		}
		
		/**
		 * 
		 * @return All managers for the nodes
		 * 
		 */
		public function get Managers():GeniManagerCollection
		{
			if(this.length == 0)
				return new GeniManagerCollection();
			var d:Dictionary = new Dictionary();
			var a:Vector.<GeniManager> = new Vector.<GeniManager>();
			var biggestManager:GeniManager;
			var max:int = 0;
			for each(var node:PhysicalNode in collection)
			{
				if(a.indexOf(node.manager) == -1)
				{
					a.push(node.manager);
					d[node.manager] = 1;
				}
				else
					d[node.manager]++;
				
				if(d[node.manager] > max)
				{
					biggestManager = node.manager as GeniManager;
					max = d[node.manager];
				}
			}
			var group:GeniManagerCollection = new GeniManagerCollection();
			group.add(biggestManager);
			for each(var m:GeniManager in a)
			{
				if(m != biggestManager)
					group.add(m);
			}
			return group;
		}
		
		/**
		 * 
		 * @return All hardware types
		 * 
		 */
		public function get HardwareTypes():HardwareTypeCollection
		{
			var types:HardwareTypeCollection = new HardwareTypeCollection();
			for each(var node:PhysicalNode in collection)
			{
				for each(var nodeType:HardwareType in node.hardwareTypes.collection)
				{
					if(types.getByName(nodeType.name) == null)
						types.add(nodeType);
				}
			}
			types.collection = types.collection.sort(
				function compareTypes(a:HardwareType, b:HardwareType):Number
				{
					if(a.name < b.name)
						return -1;
					else if(a.name == b.name)
						return 0;
					else
						return 1;
				});
			return types;
		}
		
		public function get SliverTypes():SliverTypeCollection
		{
			var types:SliverTypeCollection = new SliverTypeCollection();
			for each(var node:PhysicalNode in collection)
			{
				for each(var nodeType:SliverType in node.sliverTypes.collection)
				{
					if(types.getByName(nodeType.name) == null)
						types.add(nodeType);
				}
			}
			types.collection = types.collection.sort(
				function compareTypes(a:SliverType, b:SliverType):Number
				{
					if(a.name < b.name)
						return -1;
					else if(a.name == b.name)
						return 0;
					else
						return 1;
				});
			return types;
		}
		
		/**
		 * 
		 * @return All CPU speeds
		 * 
		 */
		public function get CpuSpeeds():Vector.<int>
		{
			var speeds:Vector.<int> = new Vector.<int>();
			for each(var node:PhysicalNode in collection)
			{
				if(node.cpuSpeed > 0)
				{
					var add:Boolean = true;
					var i:int;
					for(i = 0; i < speeds.length; i++)
					{
						if(speeds[i] == node.cpuSpeed)
						{
							add = false;
							break;
						}
						else if(speeds[i] > node.cpuSpeed)
							break;
					}
					if(add)
						speeds.splice(i, 0, node.cpuSpeed);
				}
			}
			return speeds;
		}
		
		/**
		 * 
		 * @return All RAM sizes
		 * 
		 */
		public function get RamSizes():Vector.<int>
		{
			var sizes:Vector.<int> = new Vector.<int>();
			for each(var node:PhysicalNode in collection)
			{
				if(node.cpuSpeed > 0)
				{
					var add:Boolean = true;
					var i:int;
					for(i = 0; i < sizes.length; i++)
					{
						if(sizes[i] == node.ramSize)
						{
							add = false;
							break;
						}
						else if(sizes[i] > node.ramSize)
							break;
					}
					if(add)
						sizes.splice(i, 0, node.ramSize);
				}
			}
			return sizes;
		}
	}
}