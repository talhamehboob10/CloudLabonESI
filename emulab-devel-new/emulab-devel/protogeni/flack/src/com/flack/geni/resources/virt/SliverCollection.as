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
	import com.flack.shared.resources.IdentifiableObjectCollection;

	/**
	 * Collection of slivers
	 * 
	 * @author mstrum
	 * 
	 */
	public class SliverCollection extends IdentifiableObjectCollection
	{
		public function SliverCollection(src:Array = null)
		{
			super(src);
		}
		
		public function get AllocationState():String
		{
			var states:Vector.<String> = new Vector.<String>();
			for each(var sliver:Sliver in collection)
			{
				if(states.indexOf(sliver.allocationState) == -1)
					states.push(sliver.allocationState);
			}
			return Sliver.combineAllocationStates(states);
		}
		
		public function get OperationalState():String
		{
			var states:Vector.<String> = new Vector.<String>();
			for each(var sliver:Sliver in collection)
			{
				if(states.indexOf(sliver.operationalState) == -1)
					states.push(sliver.operationalState);
			}
			return Sliver.combineOperationalStates(states);
		}
		
		/**
		 * 
		 * @param slice Slice we want components for
		 * @return All components from the given slice
		 * 
		 */
		public function getBySlice(slice:Slice):VirtualComponentCollection
		{
			var components:VirtualComponentCollection = new VirtualComponentCollection();
			for each(var component:VirtualComponent in collection)
			{
				if(component.slice == slice)
					components.add(component);
			}
			return components;
		}
		
		/**
		 * 
		 * @return Components which have been allocated
		 * 
		 */
		public function getByAllocated(value:Boolean):SliverCollection
		{
			var slivers:SliverCollection = new SliverCollection();
			for each(var sliver:Sliver in collection)
			{
				if(value == Sliver.isAllocated(sliver.allocationState))
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
		public function getByProvisioned(value:Boolean):SliverCollection
		{
			var slivers:SliverCollection = new SliverCollection();
			for each(var sliver:Sliver in collection)
			{
				if(value == Sliver.isProvisioned(sliver.allocationState))
				{
					slivers.add(sliver);
				}
			}
			return slivers;
		}
		
		/**
		 * 
		 * @return Slices for the components
		 * 
		 */
		public function get Slices():SliceCollection
		{
			var slices:SliceCollection = new SliceCollection();
			for each(var sliver:Sliver in collection)
			{
				if(!slices.contains(sliver.slice))
					slices.add(sliver.slice);
			}
			return slices;
		}
		
		public function clearStates():void
		{
			for each(var sliver:Sliver in collection)
			{
				sliver.clearState();
			}
		}
		
		public function markStaged():void
		{
			for each(var sliver:Sliver in collection)
			{
				sliver.markStaged();
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
			for each(var sliver:Sliver in collection)
			{
				if(sliver.expires != null && (d == null || sliver.expires < d))
				{
					d = sliver.expires;
				}
			}
			return d;
		}
	}
}