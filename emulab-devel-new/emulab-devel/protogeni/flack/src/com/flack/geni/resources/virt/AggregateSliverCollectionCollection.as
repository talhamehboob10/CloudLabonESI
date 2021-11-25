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
	import com.flack.geni.GeniMain;
	
	import flash.utils.Dictionary;

	public class AggregateSliverCollectionCollection
	{
		public var collection:Dictionary;
		public function AggregateSliverCollectionCollection()
		{
			collection = new Dictionary();
		}
		
		public function getOrAdd(from:AggregateSliver):AggregateSliverCollection
		{
			var sliverCollection:AggregateSliverCollection = collection[from.manager.id.full];
			if(sliverCollection == null)
			{
				sliverCollection = new AggregateSliverCollection();
				collection[from.manager.id.full] = sliverCollection;
			}
			return sliverCollection;
		}
		
		/**
		 * 
		 * @param from Object which depends on the 'to' sliver.
		 * @param to Sliver which the 'from' sliver depends on.
		 * 
		 */
		public function add(from:AggregateSliver, to:AggregateSliver):void
		{
			var sliverCollection:AggregateSliverCollection = getOrAdd(from);
			if(!sliverCollection.contains(to))
				sliverCollection.add(to);
		}
		
		public function remove(from:AggregateSliver, to:AggregateSliver):void
		{
			var sliverCollection:AggregateSliverCollection = getOrAdd(from);
			sliverCollection.remove(to);
		}
		
		public function contains(from:AggregateSliver, to:AggregateSliver):Boolean
		{
			var sliverCollection:AggregateSliverCollection = getOrAdd(from);
			return sliverCollection.contains(to);
		}
		
		public function get numDependencies():int
		{
			var length:int = 0;
			for(var managerId:String in collection)
			{
				length += collection[managerId].length;
			}
			return length;
		}
		
		public function getLinearized(slice:Slice):AggregateSliverCollection
		{
			var searchSlivers:AggregateSliverCollection = new AggregateSliverCollection();
			var orderedSlivers:AggregateSliverCollection = new AggregateSliverCollection();
			for(var managerId:String in collection)
				searchSlivers.add(slice.aggregateSlivers.getByManager(GeniMain.geniUniverse.managers.getById(managerId)));
			while(searchSlivers.length > 0)
				search(searchSlivers.collection[0], searchSlivers, orderedSlivers);
			return orderedSlivers;
		}
		
		private function search(sliver:AggregateSliver, searchSlivers:AggregateSliverCollection, orderedSlivers:AggregateSliverCollection):void
		{
			var connectedSlivers:AggregateSliverCollection = collection[sliver.manager.id.full];
			for each(var connectedSliver:AggregateSliver in connectedSlivers.collection)
			{
				if(searchSlivers.contains(connectedSliver))
					search(connectedSliver, searchSlivers, orderedSlivers);
			}
			orderedSlivers.add(sliver);
			searchSlivers.remove(sliver);
		}
	}
}