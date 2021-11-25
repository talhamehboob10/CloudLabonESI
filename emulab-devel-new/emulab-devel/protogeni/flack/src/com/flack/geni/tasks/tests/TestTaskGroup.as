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
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.tasks.TaskEvent;
	import com.flack.shared.tasks.TaskGroup;
	
	public class TestTaskGroup extends SerialTaskGroup
	{
		protected function get NextStepNumber():int
		{
			return tasks.length+1;
		}
		
		protected function get PreviousStepNumber():int
		{
			return tasks.length;
		}
		
		public function TestTaskGroup(taskFullName:String="Serial tasks", taskDescription:String="Runs tasks one after the other", taskShortName:String="", taskParent:TaskGroup=null, taskSkipErrors:Boolean=true)
		{
			super(taskFullName, taskDescription, taskShortName, taskParent, taskSkipErrors);
		}
		
		override protected function runStart():void
		{
			if(tasks.length == 0)
				startTest();
			else
				super.runStart();
		}
		
		protected function startTest():void
		{
			// override and start here!
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=true):void
		{
			super.afterComplete(addCompletedMessage);
		}
		
		protected function testFailed(msg:String = ""):void
		{
			afterError(
				new TaskError(
					"Failed #"+PreviousStepNumber + (msg.length ? ": " + msg : ""),
					TaskError.CODE_UNEXPECTED
				)
			);
		}
		
		protected function testSucceeded():void
		{
			addMessage(
				"Completed #"+PreviousStepNumber,
				description
			);
		}
		
		protected function addTest(description:String, testTask:Task, callAfterFinished:Function = null):void
		{
			addMessage(
				"Step #"+NextStepNumber+": " + description,
				description
			);
			
			if(callAfterFinished != null)
				testTask.addEventListener(TaskEvent.FINISHED, callAfterFinished);
			add(testTask);
		}
		
		protected function testsSucceeded():void
		{
			addMessage(
				"Finished",
				"All slice tests have run successfully"
			);
		}
	}
}