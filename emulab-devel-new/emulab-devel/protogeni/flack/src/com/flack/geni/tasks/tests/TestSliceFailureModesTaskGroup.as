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

package com.flack.geni.tasks.tests 
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.plugins.emulab.RawPcSliverType;
	import com.flack.geni.resources.SliverTypes;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.tasks.groups.slice.CreateSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.DeleteAggregateSliversTaskGroup;
	import com.flack.geni.tasks.groups.slice.SubmitSliceTaskGroup;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskEvent;
	
	/**
	 * Runs a series of tests to see if the code for working with slices is correct
	 * 
	 * 1. Fail at creating a slice with a bad name (give a good name)
	 * 2. Fail at submitting to a non-existant CM first
	 * 3. Fail at submitting to a non-existant CM second
	 * 
	 * @author mstrum
	 * 
	 */
	public final class TestSliceFailureModesTaskGroup extends TestTaskGroup
	{
		public var badManager:GeniManager;
		
		public function TestSliceFailureModesTaskGroup()
		{
			super(
				"Test failed slice ops",
				"Tests to make sure all code dealing with failures in slices is correct"
			);
			
			badManager = new GeniManager(GeniManager.TYPE_PROTOGENI, ApiDetails.API_PROTOGENI, IdnUrn.makeFrom("badmanager.com", IdnUrn.TYPE_AUTHORITY, "cm").full);
			badManager.url = "https://www.google.com";
			badManager.inputRspecVersion = GeniMain.usableRspecVersions.MaxVersion;
			badManager.Status = FlackManager.STATUS_VALID;
			badManager.hrn = "badmanager.cm";
		}
		
		// Try to create a slice with a bad name, let user choose good name
		override protected function startTest():void
		{
			addTest(
				"Bad slice name",
				new CreateSliceTaskGroup(
					"!@#$%^&!!!CHANGEME!!!*()-_=+",
					GeniMain.geniUniverse.user.authority
				), 
				firstMisnamedSliceFailed
			);
		}
		
		// Try to create slice with a bad sliver first, cancel remaining
		public function firstMisnamedSliceFailed(event:TaskEvent):void
		{
			var slice:Slice = (event.task as CreateSliceTaskGroup).newSlice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				testSucceeded();
				
				addMessage(
					"Preparing Step #" + NextStepNumber,
					"Preparing slice with bad sliver first"
				);
				
				var newGoodNode:VirtualNode = new VirtualNode(
					slice,
					GeniMain.geniUniverse.managers.getByHrn("utahemulab.cm"),
					"goodNode",
					true,
					RawPcSliverType.TYPE_RAWPC_V2
				);
				
				var newBadNode:VirtualNode = new VirtualNode(
					slice,
					badManager,
					"badNode",
					true,
					RawPcSliverType.TYPE_RAWPC_V2
				);
				
				// Order matters, slivers are created in the order they are added
				slice.aggregateSlivers.add(new AggregateSliver(slice, newBadNode.manager));
				slice.aggregateSlivers.add(new AggregateSliver(slice, newGoodNode.manager));
				slice.nodes.add(newGoodNode);
				slice.nodes.add(newBadNode);
				
				addTest(
					"Submit slice",
					new SubmitSliceTaskGroup(slice, false), 
					firstSliceCanceled
				);
			}
		}
		
		// Create slice with a bad second sliver
		public function firstSliceCanceled(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_CANCELED)
				testFailed();
			else
			{
				testSucceeded();
				
				addMessage(
					"Preparing Step #" + NextStepNumber,
					"Preparing slice with bad sliver second"
				);
				
				slice.aggregateSlivers.collection = slice.aggregateSlivers.collection.reverse();
				
				addTest(
					"Submit slice with a bad sliver first and good second",
					new SubmitSliceTaskGroup(slice, false), 
					firstSliceHalfCreated
				);
			}
		}
		
		public function firstSliceHalfCreated(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status == Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				testSucceeded();
				
				addTest(
					"Delete slivers",
					new DeleteAggregateSliversTaskGroup(slice.aggregateSlivers.getByAllocated(true), false)
				);
			}
		}
		
		// XXX test out removing already created slivers
		// XXX badly formated request rspec
		// XXX non-existing node
		// XXX node which is not available
	}
}