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
	import com.flack.geni.tasks.xmlrpc.am.RenewTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.RenewSliverCmTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.RenewSliceSaTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.ParallelTaskGroup;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.utils.DateUtil;
	
	/**
	 * Renews the slice and all slivers to the given date
	 * 
	 * @author mstrum
	 * 
	 */
	public final class RenewSliceTaskGroup extends ParallelTaskGroup
	{
		public var slice:Slice;
		public var expires:Date;
		
		/**
		 * 
		 * @param renewSlice Slice (and child slivers) to be renewed
		 * @param newExpiresDate Date to renew all resources to
		 * 
		 */
		public function RenewSliceTaskGroup(renewSlice:Slice,
											newExpiresDate:Date)
		{
			super(
				"Renew " + renewSlice.Name,
				"Renews the slice named " + renewSlice.Name + " until " + DateUtil.getTimeUntil(newExpiresDate) + " from now."
			);
			slice = renewSlice;
			expires = newExpiresDate;
		}
		
		override protected function runStart():void
		{
			if(tasks.length == 0)
			{
				if(slice.expires != null && expires.time < slice.expires.time)
				{
					addMessage(
						"Only aggregates need renewing",
						"Slice will expire after the new expires time, renewing aggregates",
						LogMessage.LEVEL_INFO,
						LogMessage.IMPORTANCE_HIGH
					);
					renewSlivers();
				}
				else if(slice.creator.authority != null)
					add(new RenewSliceSaTask(slice, expires));
			}
			super.runStart();
		}
		
		override public function completedTask(task:Task):void
		{
			if(task is RenewSliceSaTask)
				renewSlivers();
			super.completedTask(task);
		}
		
		private function renewSlivers():void
		{
			for each(var sliver:AggregateSliver in slice.aggregateSlivers.collection)
			{
				var sliverExpiration:Date = sliver.EarliestExpiration;
				if(sliverExpiration == null || sliverExpiration.time < expires.time)
				{
					if(sliver.manager.api.type == ApiDetails.API_GENIAM)
						add(new RenewTask(sliver, expires));
					else
						add(new RenewSliverCmTask(sliver, expires));
				}
				else
				{
					addMessage(
						"Aggregate on "+sliver.manager.hrn+" expires later",
						"Aggregate on "+sliver.manager.hrn+" expires later and doesn't need to be renewed",
						LogMessage.LEVEL_INFO,
						LogMessage.IMPORTANCE_HIGH
					);
				}
			}
		}
		
		override public function erroredTask(task:Task):void
		{
			afterError(task.error);
			cancelRemainingTasks();
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
		  var earliestSliverExpiration:Date = slice.aggregateSlivers.EarliestExpiration;
		  if(earliestSliverExpiration == null)
		  {
		    addMessage(
		      "Renewed. Slice espires in "+DateUtil.getTimeUntil(slice.expires)+".",
		      "Slice will expire in " + DateUtil.getTimeUntil(slice.expires) + ".",
		      LogMessage.LEVEL_INFO,
		      LogMessage.IMPORTANCE_HIGH
		    );
		  }
		  else
		  {
		    if(earliestSliverExpiration < slice.expires)
		    {
		      addMessage(
			"Renewed. Aggregates expire before slice in "+DateUtil.getTimeUntil(earliestSliverExpiration) +".",
			"Aggregates will start to expire in " + DateUtil.getTimeUntil(earliestSliverExpiration) + ". The slice will expire in " + DateUtil.getTimeUntil(slice.expires) + ".",
			LogMessage.LEVEL_INFO,
			LogMessage.IMPORTANCE_HIGH
		      );
		    }
		    else
		    {
		      addMessage(
			"Renewed. All expire at the same time in "+DateUtil.getTimeUntil(slice.expires)+".",
			"Aggregates and slice will start to expire in " + DateUtil.getTimeUntil(slice.expires) + ".",
			LogMessage.LEVEL_INFO,
			LogMessage.IMPORTANCE_HIGH
		      );
		    }
		  }
		  super.afterComplete(addCompletedMessage);
		}
	}
}
