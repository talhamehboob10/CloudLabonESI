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
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.logging.LogMessageCollection;
	import com.flack.shared.utils.StringUtil;
	
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	/**
	 * Base class for all tasks and task groups
	 * 
	 * @author mstrum
	 * 
	 */
	public class Task extends EventDispatcher
	{
		/**
		 * Task is not doing anything, typically because it wasn't started yet
		 */
		public static const STATE_INACTIVE:String = "Inactive";
		/**
		 * Task has been started and is running
		 */
		public static const STATE_ACTIVE:String = "Active";
		/**
		 * Task will not perform any future actions, because it was canceled, failed or successful
		 */
		public static const STATE_FINISHED:String = "Finished";
		
		/**
		 * Just a default status so it's not blank
		 */
		public static const STATUS_NA:String = "N/A";
		/**
		 * Task has been scheduled for a future time and is waiting
		 */
		public static const STATUS_DELAYED:String = "Delayed";
		/**
		 * Task is running
		 */
		public static const STATUS_RUNNING:String = "Running";
		/**
		 * Task has failed
		 */
		public static const STATUS_FAILED:String = "Failed";
		/**
		 * Task was successful
		 */
		public static const STATUS_SUCCESS:String = "Success";
		/**
		 * Task was either canceled by the user or in code
		 */
		public static const STATUS_CANCELED:String = "Canceled";
		
		/**
		 * Is the task active, inactive, or finished?
		 */
		private var _state:String = STATE_INACTIVE;
		[Bindable]
		public function get State():String
		{
			return _state;
		}
		
		/**
		 * Sets the state of the task to the given value.  Dispatches a status changed event.
		 * 
		 * If finished, sets the end time. If started, sets the beginning time.
		 * 
		 * @param newState State the task should be in
		 * 
		 */
		public function set State(newState:String):void
		{
			if(newState == _state)
				return;
			
			if(newState == STATE_ACTIVE)
				startTime = new Date();
			else if(newState == STATE_FINISHED && Status != STATUS_CANCELED)
			{
				endTime = new Date();
				/*
				var length:int = int(Math.ceil((endTime.time-startTime.time)*.001));
				addMessage(
					"Statistics",
					"Task took < " + length + " second(s) including any delay time. Task took "+numberTries+" try(s)",
					0,
					false
				);
				*/
			}
			
			_state = newState;
			dispatchStatusChange();
		}
		
		/**
		 * What is the task doing or how has it ended? Waiting, running, delayed, success, etc.
		 */
		private var _status:String = STATUS_NA;
		[Bindable]
		public function get Status():String
		{
			return _status;
		}
		/**
		 * Sets the status of the task to the given value.  Dispatches a status changed event.
		 * 
		 * @param newStatus Status the task should be in
		 * 
		 */
		public function set Status(newStatus:String):void
		{
			if(newStatus == _status)
				return;
			_status = newStatus;
			dispatchStatusChange();
		}
		
		/**
		 * Returns how many tasks are remaining.  TaskGroups overload this to account for child tasks.
		 * 
		 * @return Number of tasks, including this one, are not finished
		 * 
		 */
		public function get Remaining():int
		{
			if(this.State != Task.STATE_FINISHED)
				return 1;
			else
				return 0;
		}
		
		/**
		 * Returns how many tasks are running.  TaskGroups overload this to account for child tasks.
		 * 
		 * @return Number of tasks, including this one, are running
		 * 
		 */
		public function get Running():int
		{
			if(this.State == Task.STATE_ACTIVE)
				return 1;
			else
				return 0;
		}
		
		[Bindable]
		/**
		 * Last message for the task, look at log messages related to this task to get all
		 * 
		 * @return Last message
		 * 
		 */
		private var _message:String = "";
		[Bindable]
		public function get Message():String
		{
			return _message;
		}
		public function set Message(newMessage:String):void
		{
			if(newMessage == _message)
				return;
			_message = newMessage;
			dispatchStatusChange();
		}
		
		/**
		 * Delay in seconds before a task should run after it is ready to run
		 */
		public var delay:uint;
		
		/**
		 * Should this task retry if possible?  E.g. when the xml-rpc server returns busy
		 */
		public var retryWhenPossible:Boolean;
		/**
		 * Number of times the task should be retried before failing
		 */
		public var numberTries:int = 0;
		
		/**
		 * Seconds before the task should timeout and cancel
		 */
		public var timeout:uint;
		private var timer:Timer;
		/**
		 * Updates the message of the task while other things are happening/waiting
		 */
		protected var autoUpdate:Timer;
		
		// Benchmarks
		public var startTime:Date;
		public var endTime:Date;
		
		/**
		 * Data related to the task, either given to use when started or set while a task is running to return a value
		 */
		public var data:*;
		
		/**
		 * 
		 * @return String which names the task within context (ex. create)
		 * 
		 */
		[Bindable]
		public var shortName:String;
		/**
		 * 
		 * @return String which names the task without any context (ex. create @ utah)
		 * 
		 */
		[Bindable]
		public var fullName:String;
		/**
		 * 
		 * @return fullName if set, shortName otherwise
		 * 
		 */
		public function get Name():String
		{
			if(fullName.length > 0)
				return fullName;
			else
				return shortName;
		}
		/**
		 * 
		 * @return shortName if set, fullName otherwise
		 * 
		 */
		public function get ShortestName():String
		{
			if(shortName.length > 0)
				return shortName;
			else
				return fullName;
		}
		
		/**
		 * Description of what the task does
		 * 
		 * @return Description
		 * 
		 */
		[Bindable]
		public var description:String;
		
		/**
		 * Should be set if the task needs to convey that there are warnings
		 */
		public var hasWarnings:Boolean = false;
		/**
		 * Error which caused the task to fail
		 */
		public var error:TaskError;
		
		/**
		 * Parent task
		 */
		public var parent:TaskGroup;
		/**
		 * 
		 * @return Furthest back ancestor task which has no parent
		 * 
		 */
		public function get Root():Task
		{
			var root:Task = this;
			while(root.parent != null)
				root = root.parent;
			return root;
		}
		/**
		 * 
		 * @return All ancestor tasks
		 * 
		 */
		public function get Ancestors():TaskCollection
		{
			var ancestors:TaskCollection = new TaskCollection();
			if(parent != null)
			{
				var ancesterTask:Task = parent;
				while(ancesterTask != null)
				{
					ancestors.add(ancesterTask);
					ancesterTask = ancesterTask.parent;
				}
			}
			return ancestors;
		}
		
		/**
		 * 
		 * @return All logs related to this and only this task
		 * 
		 */
		public function get Logs():LogMessageCollection
		{
			return SharedMain.logger.Logs.getRelatedTo([this]);
		}
		
		/**
		 * Items the task is related to (e.g. manager if the task is listing resources from there)
		 */
		public var relatedTo:Array;
		
		/**
		 * Make sure this runs and next tasks don't run until done
		 */
		public var forceSerial:Boolean;
		/**
		 * Force this to run now, no matter what
		 */
		public var forceRunNow:Boolean = false;
		
		/**
		 * 
		 * @param taskFullName Name of the task, including contextual queues
		 * @param taskDescription Description of what the task does
		 * @param taskShortName Shortest name of the task understandable in context
		 * @param taskParent Parent to assign the task to
		 * @param taskTimeout Time (in ms) after which the task should be canceled if not completed by after started
		 * @param taskDelay Time to delay the task from starting after it would have started, not from right now
		 * @param taskRetryWhenPossible Retry the task if possible?  For example, if busy and can try again later.
		 * @param taskRelatedTo Objects related to the task (manager, slice, sliver, etc.)
		 * @param taskForceSerial Force this task to run by itself, even in something like a parallel task gorup
		 * 
		 */
		public function Task(taskFullName:String = "",
							 taskDescription:String = "",
							 taskShortName:String = "",
							 taskParent:TaskGroup = null,
							 taskTimeout:uint = 0,
							 taskDelay:uint = 0,
							 taskRetryWhenPossible:Boolean = true,
							 taskRelatedTo:Array = null,
							 taskForceSerial:Boolean = false)
		{
			super();
			fullName = taskFullName;
			description = taskDescription;
			shortName = taskShortName;
			parent = taskParent;
			timeout = taskTimeout;
			delay = taskDelay;
			retryWhenPossible = taskRetryWhenPossible;
			forceSerial = taskForceSerial;
			if(taskRelatedTo)
				relatedTo = taskRelatedTo;
			else
				relatedTo = [];
			ensureAllTasksInRelated();
		}
		
		/**
		 * Ensures that all ancestor tasks are listed in relatedTo
		 * 
		 */
		public function ensureAllTasksInRelated():void
		{
			if(relatedTo.indexOf(this) == -1)
				relatedTo.push(this);
			if(parent != null)
			{
				var ancesterTask:Task = parent;
				while(ancesterTask != null)
				{
					relatedTo.push(ancesterTask);
					ancesterTask = ancesterTask.parent;
				}
			}
		}
		
		/**
		 * Adds a log message for this task
		 * 
		 * @param newTitle Short name
		 * @param newMessage Long description
		 * @param level Type of message
		 * 
		 */
		public function addMessage(newTitle:String,
								   newMessage:String,
								   level:int = 0,
								   importance:int = 1,
								   setMessage:Boolean = true):LogMessage
		{
			var newLogMessage:LogMessage =
				new LogMessage(
					relatedTo,
					Name,
					newTitle,
					newMessage,
					ShortestName,
					level,
					importance,
					this
				);
			SharedMain.logger.add(newLogMessage);
			if(setMessage)
				Message = newTitle;
			if(level == LogMessage.LEVEL_WARNING)
				hasWarnings = true;
			dispatchLogged();
			return newLogMessage;
		}
		
		/**
		 * Either runs or starts the delayed run
		 * 
		 */
		public function start():void
		{
			State = STATE_ACTIVE;
			if(delay > 0)
				startDelay();
			else
				onStart();
		}
		
		/**
		 * Cancels this task and reports canceled to parent. Does nothing if already finished
		 * 
		 * Calls runCancel()
		 * 
		 */
		public function cancel():void
		{
			if(State == STATE_FINISHED)
				return;
				
			cancelTimers();
			Status = STATUS_CANCELED;
			State = STATE_FINISHED;
			addMessage(
				"Canceled",
				"Task was canceled",
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
			dispatchFinished();
			runCancel();
			if(parent != null)
				parent.canceledTask(this);
			runCleanup();
			removeHandlers();
		}
		
		/**
		 * IMPLEMENT if task needs to deal with a cancel
		 * 
		 */
		protected function runCancel():void
		{
			/* IMPLEMENT */
		}
		
		/**
		 * Stops and removes all timers
		 * 
		 */
		protected function cancelTimers():void
		{
			if (timer != null)
			{
				timer.reset();
				timer.removeEventListener(TimerEvent.TIMER, onDelay);
				timer = null;
			}
			if(autoUpdate != null)
			{
				autoUpdate.reset();
				autoUpdate.removeEventListener(TimerEvent.TIMER, onAutoUpdate);
				autoUpdate = null;
			}
		}

		/**
		 * Adds the optional delay if requested.
		 * 
		 * After delay, onStart will be called
		 * 
		 */
		protected function startDelay():void
		{
			cancelTimers();
			if (delay > 0)
			{
				timer = new Timer(delay*1000, 1);
				timer.addEventListener(TimerEvent.TIMER, onDelay);
				timer.start();
				
				autoUpdate = new Timer(1000);
				autoUpdate.addEventListener(TimerEvent.TIMER, onAutoUpdate);
				autoUpdate.start();
				
				addMessage(
					"Delayed " + delay + " seconds...",
					"Delayed for " + delay + " seconds"
				);
				Status = STATUS_DELAYED;
			}
		}
		/**
		 * Called after the delayed time, calls onStart to begin task
		 * @param evt
		 * 
		 */
		private function onDelay(evt:TimerEvent):void
		{
			cancelTimers();
			onStart();
		}
		/**
		 * Called to auto-update the message for the task, useful during periods of time when the task is waiting
		 * @param evt
		 * 
		 */
		private function onAutoUpdate(evt:TimerEvent):void
		{
			Message = "Delayed "+Math.max(0,delay-autoUpdate.currentCount)+" more seconds...";
		}
		
		/**
		 * Starts running the task and adds a timeout if specified.
		 * 
		 * Make sure to run cancelTimer() when timeout should be ignored.
		 * 
		 * Calls runStart()
		 * 
		 */
		private function onStart():void
		{
			if(timeout > 0)
				startTimeout();
			addMessage(
				"Started",
				"Task has started running"
			);
			Status = STATUS_RUNNING;
			if(parent != null)
				parent.startedTask(this);
			numberTries++;
			runStart();
		}
		/**
		 * If timeout is set, starts timeout timer to timeout the task at the timeout time...yeah, I'm a poet
		 * 
		 */
		private function startTimeout():void
		{
			cancelTimers();
			if (timeout > 0)
			{
				timer = new Timer(timeout*1000, 1);
				timer.addEventListener(TimerEvent.TIMER, onTimeout);
				timer.start();
			}
		}
		
		/**
		 * Called when a timeout occurs.
		 * Call cancelTimer() to stop this event from occuring
		 * Calls runTimeout() to see if a retry is needed
		 * 
		 * @param evt
		 * 
		 */
		private function onTimeout(evt:TimerEvent):void
		{
			timer.removeEventListener(TimerEvent.TIMER, onTimeout);
			timer.reset();
			timer = null;
			
			var msg:String = "Timeout of " + timeout + " seconds elapsed";
			addMessage(
				"Timed out after " + timeout + " seconds",
				msg,
				LogMessage.LEVEL_WARNING,
				LogMessage.IMPORTANCE_HIGH
			);
			Status = STATUS_FAILED;
			if (State == STATE_ACTIVE)
			{
				if(runTimeout())
					afterError(
						new TaskError(
							msg,
							TaskError.TIMEOUT
						)
					);
			}
		}
		
		/**
		 * Attempt to retry if possible.  EXTEND if default behavior isn't enough.
		 * Cleanup anything needed if onStart() will be called again.
		 * Default behavior is to run onStart() if retryWhenPossible is set
		 * 
		 * @return TRUE if an error should be reported (default = !retryWhenPossible)
		 * 
		 */
		protected function runTimeout():Boolean
		{
			/* EXTEND */
			
			if(retryWhenPossible)
				onStart();
			return !retryWhenPossible;
		}
		
		/**
		 * IMPLEMENT to do the task at hand
		 * 
		 * MUST call afterComplete(), afterError(), or cancel()
		 * after task is finished
		 * 
		 */
		protected function runStart():void
		{
			/* IMPLEMENT */
		}
		
		/**
		 * MUST be called after the task completes successfully.
		 * EXTEND if default behavior not enough.
		 * 
		 */
		protected function afterComplete(addCompletedMessage:Boolean = true):void
		{
			/* EXTEND */
			cancelTimers();
			Status = STATUS_SUCCESS;
			State = STATE_FINISHED;
			if(addCompletedMessage)
			{
				addMessage(
					"Completed",
					"Task has completed",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
			}
			dispatchFinished();
			if(parent != null)
			{
				parent.completedTask(this);
			}

			runCleanup();
			removeHandlers();
		}
		
		/**
		 * MUST be called after an error
		 * EXTEND if default behavior not enough.
		 * 
		 * @param taskError Details about the error which occurred
		 * 
		 */
		protected function afterError(taskError:TaskError):void
		{
			/* EXTEND */
			
			error = taskError;
			cancelTimers();
			switch(taskError.errorID)
			{
				case TaskError.CODE_PROBLEM:
					addMessage(
						"Problem: " + StringUtil.shortenString(taskError.message, 30, true),
						"Task ran into a problem stopping further progress. " + taskError.message,
						LogMessage.LEVEL_FAIL,
						LogMessage.IMPORTANCE_HIGH
					);
					break;
				case TaskError.CODE_UNEXPECTED:
					addMessage(
						"Unexpected error: " + StringUtil.shortenString(taskError.message, 30, true),
						"Task ran into an unexpected problem. " + taskError.message,
						LogMessage.LEVEL_FAIL,
						LogMessage.IMPORTANCE_HIGH
					);
					break;
				case TaskError.FAULT:
					var faultMessage:String = StringUtil.shortenString(taskError.message, 30, true);
					addMessage(
						"Fault: " + faultMessage,
						"Task encountered a fault: " + taskError.message,
						LogMessage.LEVEL_FAIL,
						LogMessage.IMPORTANCE_HIGH
					);
					break;
				case TaskError.TIMEOUT:
					addMessage(
						"Timeout",
						"Task timed out. " + taskError.message,
						LogMessage.LEVEL_FAIL,
						LogMessage.IMPORTANCE_HIGH
					);
					break;
			}
			Status = STATUS_FAILED;
			State = STATE_FINISHED;
			dispatchFinished();
			runCleanup();
			removeHandlers();
			if(parent != null)
				parent.erroredTask(this);
		}
		
		/**
		 * IMPLEMENT if cleanup needs to happen after task finishes, like removing event handlers
		 * 
		 */
		protected function runCleanup():void
		{
			/* IMPLEMENT */
		}
		
		// Used for book keeping added event handlers, automatically used and called
		private var eventTypes:Vector.<String> = new Vector.<String>();
		private var eventFunctions:Vector.<Function> = new Vector.<Function>();
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
		{
			super.addEventListener(type, listener, useCapture, priority, useWeakReference);
			eventTypes.push(type);
			eventFunctions.push(listener);
		}
		/**
		 * Removes all of the event handlers. Override this and do nothing to stop this behavior.
		 * 
		 */
		protected function removeHandlers():void
		{
			while(eventTypes.length > 0)
				removeEventListener(eventTypes.pop(), eventFunctions.pop());
		}
		
		/**
		 * Dispatches EVENT_LOGGED
		 * 
		 */
		protected function dispatchLogged():void
		{
			dispatchEvent(new TaskEvent(TaskEvent.LOGGED, this));
		}
		
		/**
		 * Dispatches EVENT_STATUS
		 * 
		 */
		protected function dispatchStatusChange():void
		{
			dispatchEvent(new TaskEvent(TaskEvent.STATUS, this));
		}
		
		/**
		 * Dispatches EVENT_FINISHED
		 * 
		 */
		protected function dispatchFinished():void
		{
			dispatchEvent(new TaskEvent(TaskEvent.FINISHED, this));
		}
		
		public function print(leftString:String = "", outputLogs:Boolean = false):String
		{
			var value:String = leftString
				+ "[Task\n"
				+ leftString + "\tState=" + State + "\n"
				+ leftString + "\tStatus=" + Status + "\n"
				+ leftString + "\tName=" + Name + "\n"
				+ leftString + "\tDescription=" + description + "\n"
				+ leftString + "\tMessage=" + _message + "\n"
				+ leftString + "]\n";
			if(error != null)
				value += leftString + "\t" + error.toString() + "\n";
			if(outputLogs)
				value + Logs.toString();
			return value + leftString + "[/Task]\n";
		}
		
		override public function toString():String
		{
			return print();
		}
	}
}
