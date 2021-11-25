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
	/**
	 * Collection of interfaces from a physical node
	 * 
	 * @author mstrum
	 * 
	 */
	public final class PhysicalInterfaceCollection
	{
		public var collection:Vector.<PhysicalInterface>;
		public function PhysicalInterfaceCollection()
		{
			collection = new Vector.<PhysicalInterface>();
		}
		
		public function add(ni:PhysicalInterface):void
		{
			collection.push(ni);
		}
		
		public function remove(vi:PhysicalInterface):void
		{
			var idx:int = collection.indexOf(vi);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(vi:PhysicalInterface):Boolean
		{
			return collection.indexOf(vi) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @param exact Should the ID be exact? Should be FALSE if only a portion of the IDN-URN is known
		 * @return Matching interface
		 * 
		 */
		public function getById(id:String,
								exact:Boolean = true):PhysicalInterface
		{
			for each(var ni:PhysicalInterface in collection)
			{
				if(ni.id.full == id)
					return ni;
				if(!exact && ni.id.full.indexOf(id) != -1)
					return ni;
			}
			return null;
		}
		
		/**
		 * 
		 * @return All links from the interfaces
		 * 
		 */
		public function get Links():PhysicalLinkCollection
		{
			var ac:PhysicalLinkCollection = new PhysicalLinkCollection();
			for each(var ni:PhysicalInterface in collection)
			{
				for each(var l:PhysicalLink in ni.links.collection)
					ac.add(l);
			}
			return ac;
		}
		
		/**
		 * 
		 * @return All nodes hosting the interfaces
		 * 
		 */
		public function get Nodes():PhysicalNodeCollection
		{
			var ac:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each(var ni:PhysicalInterface in collection)
			{
				if(!ac.contains(ni.owner))
					ac.add(ni.owner);
			}
			return ac;
		}
		
		/**
		 * 
		 * @return All locations where the interfaces exist
		 * 
		 */
		public function get Locations():PhysicalLocationCollection
		{
			var ac:PhysicalLocationCollection = new PhysicalLocationCollection();
			for each(var ni:PhysicalInterface in collection)
			{
				if(!ac.contains(ni.owner.location))
					ac.add(ni.owner.location);
			}
			return ac;
		}
	}
}