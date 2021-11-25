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
	 * Group of tasks
	 * 
	 * @author mstrum
	 * 
	 */
	public class TaskGroup extends Task
	{
		public var tasks:TaskCollection = new TaskCollection();
		
		/*
		override public function get Logs():LogMessageCollection
		{
			var owners:Array = [];
			var allTasks:TaskCollection = AllTasks;
			for each(var task:Task in allTasks.collection)
				owners.push(task);
			return SharedMain.logger.Logs.getRelatedTo(owners);
		}
		*/
		
		/**
		 * This and all tasks under it
		 * 
		 * @return All tasks
		 * 
		 */
		public function get AllTasks():TaskCollection
		{
			var allTasks:TaskCollection = new TaskCollection();
			allTasks.add(this);
			var childTasks:TaskCollection = tasks.All;
			for each(var childTask:Task in tasks.collection)
				allTasks.add(childTask);
			return allTasks;
		}
		
		/**
		 * 
		 * @return Number of all descendant tasks not finished, excluding group tasks
		 * 
		 */
		override public function get Remaining():int
		{
			var remaining:int = 0;
			var notFinished:TaskCollection = tasks.NotFinished;
			if(State != Task.STATE_FINISHED)
			{
				for each(var task:* in notFinished.collection)
					remaining += task.Remaining;
			}
			return remaining;
		}
		
		/**
		 * 
		 * @return Number of descendant tasks still running
		 * 
		 */
		override public function get Running():int
		{
			var running:int = 0;
			if(State != Task.STATE_FINISHED)
			{
				for each(var task:* in tasks.collection)
					running += task.Running;
			}
			return running;
		}
		
		/**
		 * 
		 * @param taskFullName Name of the task, including contextual queues
		 * @param taskDescription Description of what the task does
		 * @param taskShortName Shortest name of the task understandable in context
		 * @param taskParent Parent to assign the task to
		 * 
		 */
		public function TaskGroup(taskFullName:String = "",
								  taskDescription:String = "",
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
		 * Makes sure all children are finished or canceled
		 * 
		 */
		override protected function runCancel():void
		{
			Status = Task.STATUS_CANCELED;
			cancelRemainingTasks();
			super.cancel();
		}
		
		/**
		 * Cancels any child tasks which haven't completed yet
		 * 
		 */
		protected function cancelRemainingTasks():void
		{
			for each(var task:Task in tasks.collection)
			{
				if(task.State != Task.STATE_FINISHED)
					task.cancel();
			}
		}
		
		/**
		 * Cancels all unfinished tasks related to 'object'
		 * 
		 * @param object Items we will test for being related to
		 * 
		 */
		public function cancelUncompletedTasksRelatedTo(object:*):void
		{
			var remainingTasks:TaskCollection = tasks.NotFinished.All.NotFinished;
			for each(var task:Task in remainingTasks.collection)
			{
				if(task.State != Task.STATE_FINISHED && task.relatedTo.indexOf(object) != -1)
					task.cancel();
			}
		}
		
		/**
		 * Adds a task
		 * 
		 * Calls addedTask(task)
		 * 
		 * @param task
		 * 
		 */
		public function add(task:Task):void
		{
			task.parent = this;
			task.ensureAllTasksInRelated();
			tasks.add(task);
			addedTask(task);
			dispatchEvent(
				new TaskEvent(
					TaskEvent.ADDED,
					task
				)
			);
		}
		
		/**
		 * IMPLEMENT to perform any operations after a task is added as a child
		 * 
		 * @param task Task which was added
		 * 
		 */
		protected function addedTask(task:Task):void
		{
			/* IMPLEMENT */
		}
		
		/**
		 * Removes all child tasks
		 * 
		 */
		public function removeAll():void
		{
			while(tasks.length > 0)
			{
				remove(tasks.collection[0]);
			}
		}
		
		/**
		 * Removes a task
		 * 
		 * Calls removedTask(task)
		 * 
		 * @param task Child task to remove
		 * 
		 */
		public function remove(task:Task):void
		{
			task.parent = null;
			var idx:int = tasks.remove(task);
			removedTask(task, idx);
			dispatchEvent(
				new TaskEvent(
					TaskEvent.REMOVED,
					task
				)
			);
		}
		
		/**
		 * EXTEND to perform any operations after a child task is started
		 * 
		 * When overloaded, make sure to end function with: super.startedTask
		 * 
		 * @param task Child task which was removed
		 * @param idx Index where task was located
		 * 
		 */
		public function startedTask(task:Task):void
		{
			/* EXTEND */
			
			if(parent != null)
				parent.completedTask(task);
			else
				dispatchEvent(new TaskEvent(TaskEvent.CHILD_STARTED, task));
		}
		
		/**
		 * IMPLEMENT to perform any operations after a child task is removed
		 * 
		 * @param task Child task which was removed
		 * @param idx Index where task was located
		 * 
		 */
		public function removedTask(task:Task, idx:int):void
		{
			/* IMPLEMENT */
		}
		
		/**
		 * EXTEND to perform any operations after a child task errors.
		 * 
		 * When overloaded, make sure to end function with: super.erroredTask
		 * 
		 * @param task Child task which had an error
		 * 
		 */
		public function erroredTask(task:Task):void
		{
			/* EXTEND */
			
			finishedTask(task);
		}
		
		/**
		 * EXTEND to perform any operations after a task is completed
		 * 
		 * When overloaded, make sure to end function with: super.completedTask
		 * 
		 * @param task Child task which completed successfully
		 * 
		 */
		public function completedTask(task:Task):void
		{
			/* EXTEND */
			
			finishedTask(task);
		}
		
		/**
		 * EXTEND to perform any operations after a task is canceled
		 * 
		 * When overloaded, make sure to end function with: super.canceledTask
		 * 
		 * @param task Child task which was canceled
		 * 
		 */
		public function canceledTask(task:Task):void
		{
			/* EXTEND */
			
			finishedTask(task);
		}
		
		/**
		 * Ensures the parent of this task is notified or if root task dispatches CHILD_FINISHED
		 * 
		 * @param task Child task which has finished
		 * 
		 */
		public function finishedTask(task:Task):void
		{
			if(parent != null)
				parent.finishedTask(task);
			else
				dispatchEvent(new TaskEvent(TaskEvent.CHILD_FINISHED, task));
		}
		
		override public function print(leftString:String = "", outputLogs:Boolean = false):String
		{
			var value:String = leftString + "[TaskGroup]\n" + super.print(leftString + "\t", outputLogs);
			value += leftString + "\t[Tasks]\n";
			for each(var task:Task in tasks.collection)
				value += task.print(leftString + "\t\t", outputLogs);
			value += leftString + "\t[/Tasks]\n";
			return value + leftString + "[/TaskGroup]\n";
		}
	}
}