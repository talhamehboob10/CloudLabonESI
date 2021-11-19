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
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.StopSliverCmTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.ParallelTaskGroup;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.TaskError;
	
	import mx.controls.Alert;
	
	/**
	 * Stops all of the slivers in the slice
	 * 
	 * @author mstrum
	 * 
	 */
	public final class StopSliceTaskGroup extends SerialTaskGroup
	{
		public var slice:Slice;
		
		/**
		 * 
		 * @param newSlice Slice to stop all the slivers in
		 * 
		 */
		public function StopSliceTaskGroup(newSlice:Slice)
		{
			super(
				"Stop " + newSlice.Name,
				"Stops all reasources in " + newSlice.Name
			);
			slice = newSlice;
		}
		
		override protected function runStart():void
		{
			if(tasks.length == 0)
			{
				var runTasks:ParallelTaskGroup = new ParallelTaskGroup("Stop all", "Stops all the slivers");
				for each(var sliver:AggregateSliver in slice.aggregateSlivers.collection)
				{
					if(sliver.manager.api.type == ApiDetails.API_PROTOGENI)
					{
						if(sliver.manager.api.level == ApiDetails.LEVEL_FULL)
							runTasks.add(new StopSliverCmTask(sliver));
						else
						{
							var msg:String = sliver.manager.hrn + "doesn't support the full API so it cannot be stopped.";
							addMessage(
								"Sliver not stopped",
								msg,
								LogMessage.LEVEL_FAIL,
								LogMessage.IMPORTANCE_HIGH
							);
							Alert.show(msg, "Sliver not stopped");
						}
					}
					else if(sliver.manager.api.type == ApiDetails.API_GENIAM && sliver.manager.api.version >= 3)
					{
						runTasks.add(new PerformOperationalActionTask(sliver, PerformOperationalActionTask.ACTION_STOP));
					}
					else
					{
						addMessage(
							"Can't stop @ " + sliver.manager.hrn,
							"The manager " + sliver.manager.hrn + " doesn't support the stop task",
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
			if(slice.OperationalState != Sliver.OPERATIONAL_NOTREADY)
			{
				addMessage("Failed to stop", "All slivers don't report stopped");
				afterError(
					new TaskError(
						"Slivers failed to stop",
						TaskError.CODE_UNEXPECTED
					)
				);
			}
			else
			{
				addMessage("Stopped", "All slivers report stopped", LogMessage.LEVEL_INFO, LogMessage.IMPORTANCE_HIGH);
				super.afterComplete(addCompletedMessage);
			}
		}
	}
}