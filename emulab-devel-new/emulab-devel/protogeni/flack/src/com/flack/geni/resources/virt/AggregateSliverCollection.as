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
	 * Collection of slivers
	 * 
	 * @author mstrum
	 * 
	 */
	public final class AggregateSliverCollection
	{
		public var collection:Vector.<AggregateSliver>;
		public function AggregateSliverCollection()
		{
			collection = new Vector.<AggregateSliver>();
		}
		
		public function add(s:AggregateSliver):void
		{
			collection.push(s);
		}
		
		public function remove(s:AggregateSliver):void
		{
			var idx:int = collection.indexOf(s);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(s:AggregateSliver):Boolean
		{
			return collection.indexOf(s) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @return New instance with the same collection
		 * 
		 */
		public function get Clone():AggregateSliverCollection
		{
			var clone:AggregateSliverCollection = new AggregateSliverCollection();
			for each(var sliver:AggregateSliver in collection)
				clone.add(sliver);
			return clone;
		}

		/**
		 * Removes slivers which aren't created and don't have resources
		 * 
		 */
		public function cleanup():void
		{
			for(var i:int = 0; i < collection.length; i++)
			{
				var sliver:AggregateSliver = collection[i];
				if(!Sliver.isAllocated(sliver.AllocationState) && sliver.Nodes.length == 0)
				{
					remove(sliver);
					i--;
				}
			}
		}
		
		/**
		 * 
		 * @param id Sliver ID
		 * @return Sliver with the given sliver ID
		 * 
		 */
		public function getBySliverId(id:String):AggregateSliver
		{
			for each(var sliver:AggregateSliver in collection)
			{
				if(sliver.id.full == id)
					return sliver;
			}
			return null;
		}
		
		/**
		 * 
		 * @param gm Manager
		 * @return Sliver for the manager
		 * 
		 */
		public function getByManager(gm:GeniManager):AggregateSliver
		{
			for each(var sliver:AggregateSliver in collection)
			{
				if(sliver.manager == gm)
					return sliver;
			}
			return null;
		}
		
		/**
		 * 
		 * @param gmc Managers
		 * @return Slivers for the given managers
		 * 
		 */
		public function getByManagers(gmc:GeniManagerCollection):AggregateSliverCollection
		{
			var sc:AggregateSliverCollection = new AggregateSliverCollection();
			for each(var sliver:AggregateSliver in collection)
			{
				if(gmc.contains(sliver.manager))
					sc.add(sliver);
			}
			return sc;
		}
		
		/**
		 * 
		 * @param gm Manager
		 * @param slice Slice
		 * @return Sliver for the given manager in the slice and guarenteed to be added in the slice
		 * 
		 */
		public function getOrCreateByManager(gm:GeniManager, slice:Slice):AggregateSliver
		{
			var newSliver:AggregateSliver = getByManager(gm);
			if(newSliver != null)
				return newSliver;
			else
			{
				newSliver = new AggregateSliver(slice, gm);
				add(newSliver);
				return newSliver;
			}
		}
		
		/**
		 * 
		 * @return Earliest expiration date
		 * 
		 */
		public function get EarliestExpiration():Date
		{
			var d:Date = null;
			for each(var sliver:AggregateSliver in collection)
			{
				var sliverExpiration:Date = sliver.EarliestExpiration;
				if(sliverExpiration != null && (d == null || sliverExpiration < d))
				{
					sliverExpiration;
				}
			}
			return d;
		}
		
		/**
		 * 
		 * @return Components which have been allocated
		 * 
		 */
		public function getByAllocated(value:Boolean):AggregateSliverCollection
		{
			var slivers:AggregateSliverCollection = new AggregateSliverCollection();
			for each(var sliver:AggregateSliver in collection)
			{
				if(value == Sliver.isAllocated(sliver.AllocationState))
				{
					slivers.add(sliver);
				}
			}
			return slivers;
		}
		
		/**
		 * 
		 * @return Components which have been provisioned
		 * 
		 */
		public function getByProvisioned(value:Boolean):AggregateSliverCollection
		{
			var slivers:AggregateSliverCollection = new AggregateSliverCollection();
			for each(var sliver:AggregateSliver in collection)
			{
				if(value == Sliver.isProvisioned(sliver.AllocationState))
				{
					slivers.add(sliver);
				}
			}
			return slivers;
		}
		
		public function get AllocationState():String
		{
			var states:Vector.<String> = new Vector.<String>();
			for each(var sliver:AggregateSliver in collection)
			{
				var sliverState:String = sliver.AllocationState;
				if(states.indexOf(sliverState) == -1)
				{
					states.push(sliverState);
				}
			}
			
			return Sliver.combineAllocationStates(states);
		}
		
		public function get OperationalState():String
		{
			var states:Vector.<String> = new Vector.<String>();
			for each(var sliver:AggregateSliver in collection)
			{
				var sliverState:String = sliver.OperationalState;
				if(states.indexOf(sliverState) == -1)
				{
					states.push(sliverState);
				}
			}
			
			return Sliver.combineOperationalStates(states);
		}
	}
}
