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
	import com.flack.geni.plugins.emulab.EmulabBbgSliverType;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.AggregateSliverCollection;
	import com.flack.geni.resources.virt.AggregateSliverCollectionCollection;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.resources.virt.extensions.stitching.StitchingDependency;
	import com.flack.geni.tasks.process.GenerateRequestManifestTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.GetUserKeysSaTask;
	import com.flack.geni.tasks.xmlrpc.scs.ComputePathTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.tasks.TaskEvent;
	
	import flash.display.Sprite;
	
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.events.CloseEvent;
	
	/**
	 * Deletes, creates, and updates slivers based on changes to the slice.
	 * 
	 * On error: User is prompted whether to continue or cancel.
	 * If user cancels, user is prompted on whether to delete resources from slice in unknown state
	 * 
	 * @author mstrum
	 * 
	 */
	public final class SubmitSliceTaskGroup extends SerialTaskGroup
	{
		public var slice:Slice;
		
		public var deleteAggregateSlivers:AggregateSliverCollection;
		public var updateAggregateSlivers:AggregateSliverCollection;
		public var newAggregateSlivers:AggregateSliverCollection;
		
		private var comfirmWithUser:Boolean;
		private var skipUnchangedSlivers:Boolean;
		private var deletingAfterProblem:Boolean = false;
		private var prompting:Boolean = false;
		
		/**
		 * 
		 * @param submitSlice Slice to submit changes for
		 * @param shouldConfirmWithUser Ask user to confirm actions that will be taken?
		 * 
		 */
		public function SubmitSliceTaskGroup(submitSlice:Slice,
											 shouldConfirmWithUser:Boolean = true,
											 shouldSkipUnchangedSlivers:Boolean = false)
		{
			super(
				"Submit " + submitSlice.Name,
				"Submiting the slice named " + submitSlice.Name + " to be allocated"
			);
			relatedTo.push(submitSlice);
			slice = submitSlice;
			comfirmWithUser = shouldConfirmWithUser;
			skipUnchangedSlivers = shouldSkipUnchangedSlivers;
		}
		
		private function tryAgain(event:TaskEvent):void
		{
			runStart();
		}
		
		override protected function runStart():void
		{
			// First run
			if(tasks.length == 0)
			{
				// Instantiate the slice if needed
				if(!slice.Instantiated)
				{
					var instantiate:CreateSliceTaskGroup = new CreateSliceTaskGroup();
					instantiate.addEventListener(TaskEvent.FINISHED, tryAgain);
					return;
				}
				
				// Can't try to submit a slice which is empty, delete it.
				if(slice.nodes.length == 0
					&& slice.links.length == 0
					&& slice.aggregateSlivers.getByAllocated(true).length == 0)
				{
					afterError(
						new TaskError(
							"Slice cannot be empty when submitting. Either create a new slice or delete the old slice.",
							TaskError.CODE_PROBLEM
						)
					);
					return;
				}
				
				// Invalidate the slice
				slice.markStaged();
				
				// If stitching is needed, do that first.
				// TODO: Put back in when stitching is working.
				/*
				if(slice.links.Stitched.UnsubmittedChanges)
				{
					addMessage(
						"Stitching needed, computing that first.",
						slice.toString(),
						LogMessage.LEVEL_INFO,
						LogMessage.IMPORTANCE_HIGH
					);
					
					slice.ensureSliversExist();
					var createSliceRspec:GenerateRequestManifestTask = new GenerateRequestManifestTask(
						slice,
						true,
						false,
						false);
					createSliceRspec.start();
					
					add(new ComputePathTask(slice, createSliceRspec.resultRspec));
				}
				// Otherwise just calculate changes and submit.
				else
				{*/
					calculateChanges();
					
					if(tryApplyChanges())
						return;
				/*}*/
			}
			super.runStart();
		}
		
		private function calculateChanges():void
		{
			var newManagers:GeniManagerCollection = slice.Managers;
			deleteAggregateSlivers = new AggregateSliverCollection();
			updateAggregateSlivers = new AggregateSliverCollection();
			newAggregateSlivers = new AggregateSliverCollection();
			for each(var existingSliver:AggregateSliver in slice.aggregateSlivers.collection)
			{
				if(Sliver.isAllocated(existingSliver.AllocationState))
				{
					if(newManagers.contains(existingSliver.manager))
					{
						if(existingSliver.UnsubmittedChanges || !skipUnchangedSlivers)
							updateAggregateSlivers.add(existingSliver);
					}
					else
						deleteAggregateSlivers.add(existingSliver);
					newManagers.remove(existingSliver.manager);
				}
				else
					newAggregateSlivers.add(existingSliver);
			}
			for each(var newManager:GeniManager in newManagers.collection)
			{
				if(slice.aggregateSlivers.getByManager(newManager) == null)
				{
					var newSliver:AggregateSliver = new AggregateSliver(slice, newManager);
					slice.aggregateSlivers.add(newSliver);
					newAggregateSlivers.add(newSliver);
				}
			}
			
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLICE,
				slice
			);
		}
		
		private function tryApplyChanges():Boolean
		{
			if(comfirmWithUser)
			{
				var submitMsg:String = "Continue with the following actions?";
				var i:int = 0;
				if(newAggregateSlivers.length > 0)
				{
					submitMsg += "\nCreate at " + newAggregateSlivers.length + " new aggregate" + (newAggregateSlivers.length ? "s" : "");
					for(i = 0; i < newAggregateSlivers.length; i++)
						submitMsg += "\n\t@ " + newAggregateSlivers.collection[i].manager.hrn;
				}
				if(updateAggregateSlivers.length > 0)
				{
					submitMsg += "\nUpdate " + updateAggregateSlivers.length + " existing aggregate" + (updateAggregateSlivers.length ? "s" : "");
					for(i = 0; i < updateAggregateSlivers.length; i++)
						submitMsg += "\n\t@ " + updateAggregateSlivers.collection[i].manager.hrn;
				}
				if(deleteAggregateSlivers.length > 0)
				{
					submitMsg += "\nDelete " + deleteAggregateSlivers.length + " at existing aggregate" + (deleteAggregateSlivers.length ? "s" : "");
					for(i = 0; i < deleteAggregateSlivers.length; i++)
						submitMsg += "\n\t@ " + deleteAggregateSlivers.collection[i].manager.hrn;
				}
				if(slice.links.Stitched.getByAllocated(false).length > 0)
				{
					submitMsg += "\nStitch " + slice.links.Stitched.getByAllocated(false).length + " multi-aggregate links";
				}
				Alert.show(
					submitMsg,
					"Continue?",
					Alert.YES|Alert.NO,
					FlexGlobals.topLevelApplication as Sprite,
					continueChoice
					);
				return true;
			}
			else
				applyChanges();
			return false;
		}
		
		private function continueChoice(e:CloseEvent):void
		{
			if(e.detail == Alert.YES)
				applyChanges();
			else
				cancel();
		}
		
		private function applyChanges():void
		{
			// Make sure to replace existing slice if there is a disconnect
			var existingSlice:Slice = GeniMain.geniUniverse.user.slices.getById(slice.id.full);
			if(existingSlice != null && existingSlice != slice)
			{
				GeniMain.geniUniverse.user.slices.remove(existingSlice);
				GeniMain.geniUniverse.user.slices.add(slice);
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					slice
				);
			}
			
			// Make sure we have the latest keys.
			if(GeniMain.geniUniverse.user.authority != null)
				add(new GetUserKeysSaTask(GeniMain.geniUniverse.user, false));
			
			// First, delete any aggregate slivers.
			if(deleteAggregateSlivers.length > 0)
				add(new DeleteAggregateSliversTaskGroup(deleteAggregateSlivers));
			
			// Create graph w/o dependancies
			var sliverGraph:AggregateSliverCollectionCollection = new AggregateSliverCollectionCollection();
			for each(var updateSliver:AggregateSliver in updateAggregateSlivers.collection)
				sliverGraph.getOrAdd(updateSliver);
			for each(var createSliver:AggregateSliver in newAggregateSlivers.collection)
				sliverGraph.getOrAdd(createSliver);

			// Add dependancies for BBG nodes.
			for each(var node:VirtualNode in slice.nodes.collection)
			{
				if(node.sliverType.name == EmulabBbgSliverType.TYPE_EMULAB_BBG)
				{
					var connectedManagers:GeniManagerCollection = node.interfaces.Links.Interfaces.Managers;
					connectedManagers.remove(node.manager);
					for each(var connectedManager:GeniManager in connectedManagers.collection)
					{
						sliverGraph.add(slice.aggregateSlivers.getByManager(connectedManager), slice.aggregateSlivers.getByManager(node.manager));
					}
				}
			}
			
			// Add dependancies for stitching.
			if(slice.stitching != null && slice.stitching.dependencies != null)
			{
				for each(var dependency:StitchingDependency in slice.stitching.dependencies.collection)
				{
					addDependenciesFor(sliverGraph, dependency);
				}
			}
			
			// Just update & create if no dependancies
			if(sliverGraph.numDependencies == 0)
			{
				if(updateAggregateSlivers.length > 0)
					add(new UpdateAggregateSliversTaskGroup(updateAggregateSlivers));
				if(newAggregateSlivers.length > 0)
					add(new CreateAggregateSliversTaskGroup(newAggregateSlivers));
			}
			// Linearize to get create order
			else
			{
				var orderedSlivers:AggregateSliverCollection = sliverGraph.getLinearized(slice);
				for each(var orderedSliver:AggregateSliver in orderedSlivers.collection)
				{
					var sliverCollection:AggregateSliverCollection = new AggregateSliverCollection();
					sliverCollection.add(orderedSliver);
					if(updateAggregateSlivers.contains(orderedSliver))
						add(new UpdateAggregateSliversTaskGroup(sliverCollection));
					else
						add(new CreateAggregateSliversTaskGroup(sliverCollection));
				}
			}
			add(new RefreshSliceStatusTaskGroup(slice));
			
			super.runStart();
		}
		
		private function addDependenciesFor(sliverGraph:AggregateSliverCollectionCollection, dependency:StitchingDependency):void
		{
			for each(var lowerDependency:StitchingDependency in dependency.dependencies.collection)
			{
				sliverGraph.add(
					slice.aggregateSlivers.getByManager(dependency.aggregate),
					slice.aggregateSlivers.getByManager(lowerDependency.aggregate));
				addDependenciesFor(sliverGraph, lowerDependency);
			}
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(prompting)
				return;
			if(deletingAfterProblem)
			{
				addMessage("Resources deleted", slice.toString());
				super.afterError(
					new TaskError(
						"Resources deleted after slice was found to be in an unknown state",
						TaskError.CODE_PROBLEM
					)
				);
			}
			else
			{
				addMessage("Submitted", slice.toString(), LogMessage.LEVEL_INFO, LogMessage.IMPORTANCE_HIGH);
				super.afterComplete(addCompletedMessage);
			}
		}
		
		override public function completedTask(task:Task):void
		{
			if(task is ComputePathTask)
			{
				calculateChanges();
				if(tryApplyChanges())
					return;
			}
			super.completedTask(task);
		}
		
		// If any of the slice operation groups are canceled, the entire process has been canceled
		override public function canceledTask(task:Task):void
		{
			if(!deletingAfterProblem)
			{
				if(task is DeleteAggregateSliversTaskGroup
					|| task is UpdateAggregateSliversTaskGroup
					|| task is CreateAggregateSliversTaskGroup)
				{
					prompting = true;
					cancelRemainingTasks();
					notFullySubmitted();
				}
				else
					super.canceledTask(task);
			}
			else
				runStart();
		}
		
		override public function erroredTask(task:Task):void
		{
			if(!deletingAfterProblem)
			{
				if(task is DeleteAggregateSliversTaskGroup
					|| task is UpdateAggregateSliversTaskGroup
					|| task is CreateAggregateSliversTaskGroup)
				{
					prompting = true;
					cancelRemainingTasks();
					notFullySubmitted();
				}
				else
					super.erroredTask(task);
			}
			else
				runStart();
		}
		
		public function notFullySubmitted():void
		{
/*
			// ask user if they would like to delete...
			Alert.show(
				"Slice was not submitted and processed correctly. Deallocate resources so that slice isn't in an unknown state?",
				"Deallocate?",
				Alert.YES|Alert.NO,
				FlexGlobals.topLevelApplication as Sprite,
				userChoice,
				null,
				Alert.YES
			);
*/
			addMessage(
				"User didn't remove slice",
				"User decided to not delete slice which is in an unknown state",
				LogMessage.LEVEL_WARNING,
				LogMessage.IMPORTANCE_HIGH
			);
				
			afterError(
				new TaskError(
					"Slice in unkown state",
					TaskError.CODE_PROBLEM
				)
			);
		}
		
		public function userChoice(event:CloseEvent):void
		{
			prompting = false;
			if(event.detail == Alert.YES)
			{
				addMessage(
					"User removing slice",
					"User decided to remove the slice which is in an unknown state",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				deletingAfterProblem = true;
				// Run a delete at all managers
				var deleteSlivers:AggregateSliverCollection = new AggregateSliverCollection();
				for each(var deleteSliverInManager:GeniManager in GeniMain.geniUniverse.managers.collection)
				{
					if(deleteSliverInManager.Status == FlackManager.STATUS_VALID)
					{
						var deleteSliver:AggregateSliver = new AggregateSliver(slice, deleteSliverInManager);
						deleteSliver.manifest = new Rspec();
						deleteSlivers.add(deleteSliver);
					}
				}
				add(new DeleteAggregateSliversTaskGroup(deleteSlivers, false));
				
			}
			else
			{
				addMessage(
					"User didn't remove slice",
					"User decided to not delete slice which is in an unknown state",
					LogMessage.LEVEL_WARNING,
					LogMessage.IMPORTANCE_HIGH
				);
				
				afterError(
					new TaskError(
						"Slice in unkown state",
						TaskError.CODE_PROBLEM
					)
				);
			}
		}
	}
}