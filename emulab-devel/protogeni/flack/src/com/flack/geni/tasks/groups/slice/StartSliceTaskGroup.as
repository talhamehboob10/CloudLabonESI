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
	import com.flack.geni.tasks.xmlrpc.am.PerformOperationalActionTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.RestartSliverCmTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.StartSliverCmTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.ParallelTaskGroup;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.TaskError;
	
	/**
	 * Starts all of the resources in a slice
	 * 
	 * @author mstrum
	 * 
	 */
	public final class StartSliceTaskGroup extends SerialTaskGroup
	{
		public var slice:Slice;
		
		/**
		 * 
		 * @param newSlice Slice to start all resources in
		 * 
		 */
		public function StartSliceTaskGroup(newSlice:Slice)
		{
			super(
				"Start " + newSlice.Name,
				"Starts all reasources in " + newSlice.Name
			);
			relatedTo.push(newSlice);
			slice = newSlice;
		}
		
		override protected function runStart():void
		{
			if(tasks.length == 0)
			{
				var runTasks:ParallelTaskGroup = new ParallelTaskGroup("Start all", "Starts all the slivers");
				for each(var sliver:AggregateSliver in slice.aggregateSlivers.collection)
				{
					if(sliver.manager.api.type == ApiDetails.API_PROTOGENI)
					{
						if(sliver.manager.api.level == ApiDetails.LEVEL_FULL)
							runTasks.add(new StartSliverCmTask(sliver));
						else // XXX this either needs to be optional or perhaps ask the user?
							runTasks.add(new RestartSliverCmTask(sliver));
					}
					else if(sliver.manager.api.type == ApiDetails.API_GENIAM && sliver.manager.api.version >= 3)
					{
						runTasks.add(new PerformOperationalActionTask(sliver, PerformOperationalActionTask.ACTION_STOP));
					}
					else
					{
						addMessage(
							"Can't start @ " + sliver.manager.hrn,
							"The manager " + sliver.manager.hrn + " doesn't support the start task",
							LogMessage.LEVEL_INFO,
							LogMessage.IMPORTANCE_HIGH);
					}
				}
				add(runTasks);
				add(new RefreshSliceStatusTaskGroup(slice));
			}
			super.runStart();
		}
		
		// Sanity check
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(slice.OperationalState != Sliver.OPERATIONAL_READY)
			{
				addMessage("Failed to start", "All slivers don't report ready");
				afterError(
					new TaskError(
						"Slivers failed to start",
						TaskError.CODE_UNEXPECTED
					)
				);
			}
			else
			{
				addMessage("Started", "All slivers report ready");
				super.afterComplete(addCompletedMessage);
			}
		}
	}
}