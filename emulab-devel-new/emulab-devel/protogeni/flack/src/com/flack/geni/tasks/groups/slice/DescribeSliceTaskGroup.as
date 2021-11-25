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
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.AggregateSliverCollection;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.geni.tasks.xmlrpc.am.DescribeTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.GetSliverCmTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.tasks.ParallelTaskGroup;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	
	/**
	 * Gets all information about an existing slice
	 * 
	 * 1. If resolveSlice and user has authority...
	 *  1a. ResolveSliceSaTask
	 *  1b. GetSliceCredentialSaTask
	 * 2. For each manager...
	 *    If queryAllManagers, or in slice.reportedManagers, or non-ProtoGENI, or no slice authority
	 *  2a. ListSliverResourcesTask/GetSliverCmTask
	 *  2b. ParseManifestTask
	 * 
	 * @author mstrum
	 * 
	 */
	public final class DescribeSliceTaskGroup extends ParallelTaskGroup
	{
		public var slice:Slice;
		public var resolveSlice:Boolean;
		public var queryAllManagers:Boolean;
		private var parseTasks:SerialTaskGroup;
		
		/**
		 * 
		 * @param taskSlice Slice to get everything for
		 * @param shouldResolveSlice Resolve the slice?
		 * @param shouldQueryAllManagers Query all managers? Needed if resources exist at non-ProtoGENI managers.
		 * 
		 */
		public function DescribeSliceTaskGroup(taskSlice:Slice,
											   shouldQueryAllManagers:Boolean = false)
		{
			super(
				"Describe " + taskSlice.Name,
				"Gets all infomation about slice with id: " + taskSlice.id.full
			);
			relatedTo.push(taskSlice);
			slice = taskSlice;
			queryAllManagers = shouldQueryAllManagers;
		}
		
		override protected function runStart():void
		{
			if(tasks.length == 0)
			{
				slice.aggregateSlivers = new AggregateSliverCollection();
				for each(var manager:GeniManager in GeniMain.geniUniverse.managers.collection)
				{
					if(manager.type != GeniManager.TYPE_PROTOGENI ||
						slice.creator.authority == null ||
						slice.reportedManagers.contains(manager) ||
						queryAllManagers)
					{
						if(manager.Status == FlackManager.STATUS_VALID)
						{
							var newGeniSliver:AggregateSliver = new AggregateSliver(slice, manager);
							if(manager.api.type == ApiDetails.API_GENIAM)
								add(new DescribeTask(newGeniSliver));
							else
								add(new GetSliverCmTask(newGeniSliver));
						}
						else
						{
							addMessage(
								"Skipping " + manager.hrn,
								"Skipping " + manager.hrn + " which doesn't have a valid advertisement loaded.  There could be a sliver at this manager.",
								LogMessage.LEVEL_WARNING);
						}
						
					}
				}
			}
				
			super.runStart();
		}
		
		override public function completedTask(task:Task):void
		{
			if(task is SerialTaskGroup)
			{
				addMessage(
					"Retrieved",
					slice.Name + " has been retrieved. " +
						slice.nodes.length + " nodes and " + slice.links.length + " links were found on "+slice.aggregateSlivers.length+" managers.",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					slice,
					FlackEvent.ACTION_POPULATED
				);
				
				add(new RefreshSliceStatusTaskGroup(slice));
			}
			else if(task is RefreshSliceStatusTaskGroup)
			{
				addMessage(
					"Finished",
					"All status has been finalized.",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
			}
			super.completedTask(task);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(parseTasks != null && parseTasks.State == Task.STATE_INACTIVE)
				add(parseTasks);
			else
				super.afterComplete(addCompletedMessage);
		}
		
		override public function add(task:Task):void
		{
			// put the advertisement parsing in their own serial group
			if(task is ParseRequestManifestTask)
			{
				if(parseTasks == null)
				{
					parseTasks =
						new SerialTaskGroup(
							"Parse manifests",
							"Parses the manifest RSPECs for " + slice.Name
						);
				}
				parseTasks.add(task);
			}
			else
				super.add(task);
		}
		
		override public function erroredTask(task:Task):void
		{
			if(parseTasks == task)
				afterError(task.error);
			else
				super.erroredTask(task);
		}
	}
}