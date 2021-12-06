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
	 * Collection of tasks
	 * 
	 * @author mstrum
	 * 
	 */
	public final class TaskCollection
	{
		public var collection:Vector.<Task>;
		public function TaskCollection()
		{
			collection = new Vector.<Task>();
		}
		
		public function add(task:Task):void
		{
			collection.push(task);
		}
		
		public function remove(task:Task):int
		{
			var idx:int = collection.indexOf(task);
			if(idx > -1)
				collection.splice(idx, 1);
			return idx;
		}
		
		public function contains(task:Task):Boolean
		{
			return collection.indexOf(task) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @return Same collection as an Array
		 * 
		 */
		public function get AsArray():Array
		{
			var array:Array = [];
			for each(var childTask:Task in collection)
				array.push(childTask);
			return array;
		}
		
		/**
		 * 
		 * @return Combination of all relatedTo values in tasks
		 * 
		 */
		public function get RelatedTo():Array
		{
			var relatedTo:Array = [];
			for each(var childTask:Task in collection)
			{
				for each(var childTaskRelatedTo:* in childTask.relatedTo)
				{
					if(relatedTo.indexOf(childTaskRelatedTo) == -1)
						relatedTo.push(childTaskRelatedTo);
				}
			}
			return relatedTo;
		}
		
		/**
		 * 
		 * @return All tasks including child tasks
		 * 
		 */
		public function get All():TaskCollection
		{
			var allTasks:TaskCollection = new TaskCollection();
			for each(var childTask:Task in collection)
			{
				if(childTask is TaskGroup)
				{
					allTasks.add(childTask);
					var childTasks:TaskCollection = (childTask as TaskGroup).tasks.All;
					for each(var childsTask:* in childTasks.collection)
						allTasks.add(childsTask);
				}
				else
					allTasks.add(childTask);
			}
			return allTasks;
		}
		
		/**
		 * 
		 * @return Inactive tasks
		 * 
		 */
		public function get Inactive():TaskCollection
		{
			return getWithState(Task.STATE_INACTIVE);
		}
		
		/**
		 * 
		 * @return Active tasks
		 * 
		 */
		public function get Active():TaskCollection
		{
			return getWithState(Task.STATE_ACTIVE);
		}
		
		/**
		 * 
		 * @return Tasks which haven't finished
		 * 
		 */
		public function get NotFinished():TaskCollection
		{
			return getOtherThanState(Task.STATE_FINISHED);
		}
		
		/**
		 * 
		 * @return All tasks including descendants which aren't finished 
		 * 
		 */
		public function get AllNotFinished():TaskCollection
		{
			return NotFinished.All.NotFinished;
		}
		
		/**
		 * 
		 * @param state State which the tasks should be in
		 * @return Tasks which are in the given state
		 * 
		 */
		public function getWithState(state:String):TaskCollection
		{
			var newTasks:TaskCollection = new TaskCollection();
			for each(var task:Task in collection)
			{
				if(task.State == state)
					newTasks.add(task);
			}
			return newTasks;
		}
		
		/**
		 * 
		 * @param state State the tasks should not be in
		 * @return Tasks not in the given state
		 * 
		 */
		public function getOtherThanState(state:String):TaskCollection
		{
			var newTasks:TaskCollection = new TaskCollection();
			for each(var task:Task in collection)
			{
				if(task.State != state)
					newTasks.add(task);
			}
			return newTasks;
		}
		
		/**
		 * 
		 * @param type Class of tasks we are looking for
		 * @return Tasks which are of the Class given
		 * 
		 */
		public function getOfClass(type:Class):TaskCollection
		{
			var newTasks:TaskCollection = new TaskCollection();
			for each(var task:Task in collection)
			{
				if(task is type)
					newTasks.add(task);
			}
			return newTasks;
		}
		
		/**
		 * 
		 * @param item Item which tasks should be related to
		 * @return Tasks related to 'item'
		 * 
		 */
		public function getRelatedTo(item:*):TaskCollection
		{
			var newTasks:TaskCollection = new TaskCollection();
			for each(var task:Task in collection)
			{
				if(task.relatedTo.indexOf(item) != -1)
					newTasks.add(task);
			}
			return newTasks;
		}
		
		/**
		 * 
		 * @param items Items which tasks should be related to
		 * @return Tasks related to any items from 'items'
		 * 
		 */
		public function getRelatedToAny(items:Array):TaskCollection
		{
			var newTasks:TaskCollection = new TaskCollection();
			for each(var task:Task in collection)
			{
				for each(var item:* in items)
				{
					if(task.relatedTo.indexOf(item) != -1)
					{
						newTasks.add(task);
						break;
					}
				}
			}
			return newTasks;
		}
	}
}