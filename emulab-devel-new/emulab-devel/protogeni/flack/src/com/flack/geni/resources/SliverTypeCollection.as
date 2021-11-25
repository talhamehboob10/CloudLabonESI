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

package com.flack.geni.resources
{
	/**
	 * Collection of slivers
	 * 
	 * @author mstrum
	 * 
	 */
	public class SliverTypeCollection
	{
		public var collection:Vector.<SliverType>;
		public function SliverTypeCollection()
		{
			collection = new Vector.<SliverType>();
		}
		
		public function add(type:SliverType):void
		{
			collection.push(type);
		}
		
		public function remove(type:SliverType):void
		{
			var idx:int = collection.indexOf(type);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(type:SliverType):Boolean
		{
			return collection.indexOf(type) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param name Name of sliver_type to get
		 * @return Sliver type with the given name
		 * 
		 */
		public function getByName(name:String):SliverType
		{
			for each(var type:SliverType in collection)
			{
				if(type.name == name)
					return type;
			}
			return null;
		}
		
		/**
		 * 
		 * @return All disk images listed in the sliver types
		 * 
		 */
		public function get DiskImages():DiskImageCollection
		{
			var results:DiskImageCollection = new DiskImageCollection();
			for each(var type:SliverType in collection)
			{
				for each(var image:DiskImage in type.diskImages.collection)
				{
					if(!results.contains(image))
						results.add(image);
				}
			}
			return results;
		}
	}
}