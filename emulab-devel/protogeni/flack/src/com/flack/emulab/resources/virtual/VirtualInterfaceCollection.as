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

package com.flack.emulab.resources.virtual
{
	/**
	 * Collection of slices
	 * 
	 * @author mstrum
	 * 
	 */
	public final class VirtualInterfaceCollection
	{
		public var collection:Vector.<VirtualInterface>;
		public function VirtualInterfaceCollection()
		{
			collection = new Vector.<VirtualInterface>();
		}
		
		public function add(slice:VirtualInterface):void
		{
			collection.push(slice);
		}
		
		public function remove(slice:VirtualInterface):void
		{
			var idx:int = collection.indexOf(slice);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(slice:VirtualInterface):Boolean
		{
			return collection.indexOf(slice) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get Clone():VirtualInterfaceCollection
		{
			var ifaces:VirtualInterfaceCollection = new VirtualInterfaceCollection();
			for each(var iface:VirtualInterface in collection)
				ifaces.add(iface);
			return ifaces;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @return Slice with the given ID
		 * 
		 */
		public function getByName(name:String):VirtualInterface
		{
			for each(var existing:VirtualInterface in collection)
			{
				if(existing.name == name)
					return existing;
			}
			return null;
		}
		
		public function getByHost(node:VirtualNode):VirtualInterface
		{
			for each(var existing:VirtualInterface in collection)
			{
				if(existing.node == node)
					return existing;
			}
			return null;
		}
		
		public function get Links():VirtualLinkCollection
		{
			var links:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var testInterface:VirtualInterface in collection)
			{
				if(!links.contains(testInterface.link))
					links.add(testInterface.link);
			}
			return links;
		}
		
		public function get Nodes():VirtualNodeCollection
		{
			var nodes:VirtualNodeCollection = new VirtualNodeCollection();
			for each(var testInterface:VirtualInterface in collection)
			{
				if(!nodes.contains(testInterface.node))
					nodes.add(testInterface.node);
			}
			return nodes;
		}
	}
}