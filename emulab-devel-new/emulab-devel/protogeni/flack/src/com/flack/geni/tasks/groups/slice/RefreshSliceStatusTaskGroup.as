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

package com.flack.geni.tasks.groups.slice
{
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.tasks.xmlrpc.am.StatusTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.SliverStatusCmTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.ParallelTaskGroup;
	
	/**
	 * Refresh the status of the slice, slivers and all resources
	 * @author mstrum
	 * 
	 */
	public final class RefreshSliceStatusTaskGroup extends ParallelTaskGroup
	{
		public var slice:Slice;
		public var continueUntilDone:Boolean;
		
		/**
		 * 
		 * @param newSlice Slice to refresh the status for
		 * @param shouldContinueUntilDone Continue running until all statuses are finalized?
		 * 
		 */
		public function RefreshSliceStatusTaskGroup(newSlice:Slice,
													shouldContinueUntilDone:Boolean = true)
		{
			super(
				"Refresh status for " + newSlice.Name,
				"Refreshes status for all aggregates on " + newSlice.Name
			);
			relatedTo.push(newSlice);
			slice = newSlice;
			continueUntilDone = shouldContinueUntilDone;
		}
		
		override protected function runStart():void
		{
			if(tasks.length == 0)
			{
				slice.clearStatus();
				for each(var addedSliver:AggregateSliver in slice.aggregateSlivers.collection)
				{
					if(addedSliver.manager.api.type == ApiDetails.API_GENIAM)
						add(new StatusTask(addedSliver, continueUntilDone));
					else
						add(new SliverStatusCmTask(addedSliver, continueUntilDone));
				}
			}
			super.runStart();
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			var sliceState:String = Sliver.describeState(slice.AllocationState, slice.OperationalState);
			addMessage(
				sliceState,
				"Slice state has been reported to be " + sliceState,
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
			
			super.afterComplete(addCompletedMessage);
		}
	}
}
