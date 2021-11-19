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
	import com.flack.geni.plugins.instools.Instools;
	import com.flack.geni.plugins.instools.instasks.InstrumentizeSliceGroupTask;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.tasks.groups.slice.CreateSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.ImportSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.SubmitSliceTaskGroup;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskEvent;
	import com.flack.shared.tasks.http.HttpTask;
	
	/**
	 * Runs a series of tests to see if the code for working with slices is correct
	 * 
	 * @author mstrum
	 * 
	 */
	public final class TestCcrTaskGroup extends TestTaskGroup
	{
		public function TestCcrTaskGroup()
		{
			super(
				"Test CCR",
				"Test CCR"
			);
		}
		
		override protected function startTest():void
		{
			addTest(
				"Download RSPEC",
				new HttpTask("http://protogeni.net/tutorial.xml"), 
				submitSlice
			);
		}
		
		public function submitSlice(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				testSucceeded();
				
				data = event.task.data;
				
				addTest(
					"Create slice",
					new CreateSliceTaskGroup(
						"test" + Math.floor(Math.random()*10000000),
						GeniMain.geniUniverse.user.authority
					),
					firstSliceCreated
				);
			}
			
		}
		
		// 3a. Import slice from RSPEC
		public function firstSliceCreated(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				testSucceeded();
				
				addTest(
					"Import slice",
					new ImportSliceTaskGroup((event.task as CreateSliceTaskGroup).newSlice, data),
					firstSliceImported
				);
			}
		}
		
		// 3b. Check
		// 4a. Submit
		public function firstSliceImported(event:TaskEvent):void
		{
			var slice:Slice = (event.task as ImportSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				addMessage(
					"Step #"+PreviousStepNumber + ":Slice details",
					slice.toString()
				);
				
				testSucceeded();
				
				addTest(
					"Submit slice",
					new SubmitSliceTaskGroup(slice, false),
					firstSliceSubmitted);
			}
		}
		
		// 3b. Check
		// 4a. Submit
		public function firstSliceSubmitted(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed();
			else
			{
				addMessage(
					"Step #"+PreviousStepNumber + ":Slice details",
					slice.toString()
				);
				
				testSucceeded();
				
				addTest(
					"Instrumentize slice",
					new InstrumentizeSliceGroupTask(
						Instools.resetSliceDetails(
							slice,
							true,
							1,
							false
						)
					)
				);
			}
		}
	}
}