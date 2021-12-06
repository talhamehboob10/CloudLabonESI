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
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.tasks.groups.slice.CreateSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.DeleteAggregateSliversTaskGroup;
	import com.flack.geni.tasks.groups.slice.SubmitSliceTaskGroup;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskEvent;
	
	/**
	 * 
	 * 1. Create Slice
	 * 2. Add 3 nodes and submit
	 * 3. Undo until the first node was added and submit
	 * 4. Redo until the 3 nodes are back and submit
	 * 5. Deallocate
	 * 
	 * @author mstrum
	 * 
	 */
	public final class TestSliceHistoryTaskGroup extends TestTaskGroup
	{
		public function TestSliceHistoryTaskGroup()
		{
			super(
				"Slice history test",
				"Tests the history feature"
			);
		}
		
		override protected function startTest():void
		{
			addTest(
				"Create slice",
				new CreateSliceTaskGroup(
					"test" + Math.floor(Math.random()*1000000),
					GeniMain.geniUniverse.user.authority
				), 
				firstSliceCreated
			);
		}
		
		public function firstSliceCreated(event:TaskEvent):void
		{
			var slice:Slice = (event.task as CreateSliceTaskGroup).newSlice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				testSucceeded();
				
				addMessage(
					"Preparing Step #" + NextStepNumber,
					"Preparing slice with a history"
				);
				
				var addFirstNode:VirtualNode = new VirtualNode(
					slice,
					GeniMain.geniUniverse.managers.getByHrn("utahemulab.cm"),
					"test0",
					true,
					RawPcSliverType.TYPE_RAWPC_V2
				);
				slice.nodes.add(addFirstNode);
				slice.history.stateName = "Added first node";
				slice.pushState();
				
				var addSecondNode:VirtualNode = new VirtualNode(
					slice,
					addFirstNode.manager,
					"test1",
					true,
					RawPcSliverType.TYPE_RAWPC_V2
				);
				slice.nodes.add(addSecondNode);
				slice.history.stateName = "Added second node";
				slice.pushState();
				
				var addThirdNode:VirtualNode = new VirtualNode(
					slice,
					addFirstNode.manager,
					"test2",
					true,
					RawPcSliverType.TYPE_RAWPC_V2
				);
				slice.nodes.add(addThirdNode);
				slice.history.stateName = "Added third node";
				
				addTest(
					"Submit slice",
					new SubmitSliceTaskGroup(slice), 
					firstSliceSubmitted
				);
			}
		}
		
		public function firstSliceSubmitted(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				addMessage(
					"Slice details post-submit",
					slice.toString()
				);
				
				testSucceeded();
				
				addMessage(
					"Preparing Step #" + NextStepNumber,
					"Undoing history until the oldest history item"
				);
				
				var oldState:String = "";
				while(slice.history.backIndex > -1)
				{
					addMessage(
						"Slice state popped",
						slice.toString()
					);
					oldState = slice.backState();
				}
				
				addMessage(
					"Slice details pre-submit",
					slice.toString()
				);
				
				addTest(
					"Submit slice",
					new SubmitSliceTaskGroup(slice), 
					backToStartSliceSubmitted
				);
			}
		}
		
		public function backToStartSliceSubmitted(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				addMessage(
					"Slice details post-submit",
					slice.toString()
				);
				
				testSucceeded();
				
				addMessage(
					"Preparing Step #" + NextStepNumber,
					"Going forward to the latest history item"
				);
				
				var oldState:String = "";
				slice.forwardState();
				while(slice.CanGoForward)
				{
					addMessage(
						"Slice state popped",
						slice.toString()
					);
					oldState = slice.forwardState();
				}
				
				addMessage(
					"Slice details pre-submit",
					slice.toString()
				);
				
				addTest(
					"Submit slice",
					new SubmitSliceTaskGroup(slice), 
					finishedSliceSubmitted
				);
			}
		}
		
		public function finishedSliceSubmitted(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				addMessage(
					"Slice details post-submit",
					slice.toString()
				);
				
				testSucceeded();
				
				addTest(
					"Submit slice",
					new DeleteAggregateSliversTaskGroup(slice.aggregateSlivers, false)
				);
			}
		}
	}
}