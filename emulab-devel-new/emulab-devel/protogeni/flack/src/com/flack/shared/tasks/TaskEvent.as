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
	import flash.events.Event;
	
	/**
	 * Describes an event for a task
	 * 
	 * @author mstrum
	 * 
	 */
	public class TaskEvent extends Event
	{
		// Events related to the task
		/**
		 * Task has finished in any status (canceled, success, or failed)
		 */
		public static const FINISHED:String = "finished";
		/**
		 * The status has changed (canceled, success, or failed)
		 */
		public static const STATUS:String = "status";
		/**
		 * A log message has been added
		 */
		public static const LOGGED:String = "logged";
		// Events related to child tasks
		/**
		 * A child task has started
		 */
		public static const CHILD_STARTED:String = "child_started";
		/**
		 * A child task was added
		 */
		public static const ADDED:String = "added";
		/**
		 * A child task was removed
		 */
		public static const REMOVED:String = "removed";
		/**
		 * A child task finished in any status (canceled, success, or failed)
		 */
		public static const CHILD_FINISHED:String = "child_finished";
		
		/**
		 * Task which this event is related to
		 */
		public var task:Task;
		
		/**
		 * 
		 * @param type Type of event
		 * @param newTask Task where the event comes from
		 * 
		 */
		public function TaskEvent(type:String,
								  newTask:Task = null)
		{
			super(type);
			task = newTask;
		}
	}
}