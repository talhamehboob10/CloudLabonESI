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

package com.flack.shared.tasks
{
	/**
	 * Runs all child tasks at the same time.
	 * 
	 * Default behavior when a child...
	 * 
	 * Errors: Continue others...
	 * Canceled: Continue others...
	 * 
	 * @author mstrum
	 * 
	 */
	public class ParallelTaskGroup extends TaskGroup
	{
		/**
		 * Limits number of tasks running in parallel, including all descendants
		 */
		public var limitRunningCount:int = int.MAX_VALUE;
		
		/**
		 * 
		 * @param taskFullName Name of the task, including contextual queues
		 * @param taskDescription Description of what the task does
		 * @param taskShortName Shortest name of the task understandable in context
		 * @param taskParent Parent to assign the task to
		 * 
		 */
		public function ParallelTaskGroup(taskFullName:String = "Parallel tasks",
										  taskDescription:String = "Runs all tasks at the same time",
										  taskShortName:String = "",
										  taskParent:TaskGroup = null)
		{
			super(
				taskFullName,
				taskDescription,
				taskShortName,
				taskParent
			);
		}
		
		/**
		 * Starts any inactive child task unless group is inactive or if running a task with forceSerial set
		 * 
		 */
		override protected function runStart():void
		{
			// Not started yet
			if(State == Task.STATE_INACTIVE)
				return;
			// Running a serial task
			var running:TaskCollection = tasks.Active;
			if(running.length > 0 && running.collection[0].forceSerial)
				return;
			
			var inactiveTasks:TaskCollection = tasks.Inactive;
			for each(var task:Task in inactiveTasks.collection)
			{
				if(Running >= limitRunningCount)
					return;
				if(!task.forceSerial || Running == 0)
				{
					task.start();
					if(task.forceSerial)
					{
						completeIfFinished(false);
						return;
					}
				}
			}
			completeIfFinished(false);
		}
		
		/**
		 * Signals complete if all child tasks are done
		 * 
		 */
		public function completeIfFinished(tryStarting:Boolean = true):void
		{
			for each(var task:Task in tasks.collection)
			{
				if(task.State != Task.STATE_FINISHED)
				{
					if(tryStarting)
						runStart();
					return;
				}
			}

			afterComplete();
		}
		
		/**
		 * Starts the task if the group is active
		 * 
		 * @param task Child task which was added
		 * 
		 */
		override protected function addedTask(task:Task):void
		{
			if(task.forceRunNow)
				task.start();
			
			runStart();
		}
		
		/**
		 * Signals the group is done if last task
		 * 
		 * @param task Child task which completed
		 * 
		 */
		override public function completedTask(task:Task):void
		{
			super.completedTask(task);
			completeIfFinished();
		}
		
		/**
		 * Signals the group is done if last task
		 * 
		 * @param task Child task which errored
		 * 
		 */
		override public function erroredTask(task:Task):void
		{
			super.erroredTask(task);
			completeIfFinished();
		}
		
		/**
		 * Signals the group is done if last task and task isn't cancelled
		 * 
		 * @param task Child task which was canceled
		 * 
		 */
		override public function canceledTask(task:Task):void
		{
			super.canceledTask(task);
			if(Status != Task.STATUS_CANCELED)
				completeIfFinished();
		}
	}
}
