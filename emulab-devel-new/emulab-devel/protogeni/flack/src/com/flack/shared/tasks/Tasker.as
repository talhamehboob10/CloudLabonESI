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
	import com.flack.shared.utils.ArrayUtil;

	/**
	 * Manages all tasks/task groups, generally only one instance is needed
	 * 
	 * @author mstrum
	 * 
	 */
	public class Tasker extends ParallelTaskGroup
	{
		public function Tasker()
		{
			super(
				"Tasker",
				"Handles all tasks, running tasks in parallel if they don't have overlapping dependencies"
			);
			State = Task.STATE_ACTIVE;
		}
		
		/**
		 * Follows the following:
		 * If inactive, don't start anything new
		 * If running a task which uses forceSerial, wait to start the next task until it has finished
		 * Otherwise start any tasks until the parallel running limit is hit, but skip tasks which depend on active tasks
		 * 
		 */
		override protected function runStart():void
		{
			// Not started yet
			if(State == Task.STATE_INACTIVE)
				return;
			// Running a serial task
			var running:TaskCollection = tasks.Active;
			var runningRelatedTo:Array = running.All.RelatedTo;
			if(running.length > 0 && running.collection[0].forceSerial)
				return;
			
			var inactiveTasks:TaskCollection = tasks.Inactive;
			for each(var task:Task in inactiveTasks.collection)
			{
				// Already at the limit, don't start any more
				if(Running >= limitRunningCount)
					return;
				// Don't run if potential new task has dependencies (is related) to a task running
				if(ArrayUtil.overlap(runningRelatedTo, task.relatedTo))
					continue;
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
		
		override protected function removeHandlers():void
		{
			// don't remove the handlers, they should always exist
		}
	}
}