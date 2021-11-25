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
	/**
	 * Collection of slices
	 * 
	 * @author mstrum
	 * 
	 */
	public final class SliceCollection
	{
		public var collection:Vector.<Slice>;
		public function SliceCollection()
		{
			collection = new Vector.<Slice>();
		}
		
		public function add(slice:Slice):void
		{
			collection.push(slice);
		}
		
		public function remove(slice:Slice):void
		{
			var idx:int = collection.indexOf(slice);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(slice:Slice):Boolean
		{
			return collection.indexOf(slice) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @return Slice with the given ID
		 * 
		 */
		public function getById(id:String):Slice
		{
			for each(var existing:Slice in collection)
			{
				if(existing.id.full == id)
					return existing;
			}
			return null;
		}
		
		/**
		 * 
		 * @param name Slice name
		 * @return Slice with the given name
		 * 
		 */
		public function getByName(name:String):Slice
		{
			for each(var existing:Slice in collection)
			{
				if(existing.Name == name)
					return existing;
			}
			return null;
		}
		
		/**
		 * 
		 * @return Nodes from all the slices
		 * 
		 */
		public function get Nodes():VirtualNodeCollection
		{
			var nodes:VirtualNodeCollection = new VirtualNodeCollection();
			for each(var existing:Slice in collection)
			{
				for each(var node:VirtualNode in existing.nodes.collection)
					nodes.add(node);
			}
			return nodes;
		}
		
		/**
		 * 
		 * @return Links from all the slices
		 * 
		 */
		public function get Links():VirtualLinkCollection
		{
			var links:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var existing:Slice in collection)
			{
				for each(var link:VirtualLink in existing.links.collection)
					links.add(link);
			}
			return links;
		}
	}
}