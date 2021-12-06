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

package com.flack.shared.logging
{
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	
	import flash.events.EventDispatcher;

	/**
	 * Top level handler for log messages throughout the geni library
	 * 
	 * @author mstrum
	 * 
	 */
	public class Logger extends EventDispatcher
	{
		private var _logs:LogMessageCollection;
		public function get Logs():LogMessageCollection
		{
			return _logs;
		}
		
		public function Logger()
		{
			_logs = new LogMessageCollection();
		}
		
		/**
		 * Adds the message and dispatches an event
		 * 
		 * @param msg Message to add
		 * 
		 */
		public function add(msg:LogMessage):void
		{
			_logs.add(msg);
			dispatchEvent(new FlackEvent(FlackEvent.CHANGED_LOG, msg, FlackEvent.ACTION_CREATED));
		}
		
		/**
		 * Dispatches a selected event for the owner.  Kind of dirty, but not used very much.
		 * 
		 * @param owner null or tasker indicates all messages, otherwise owner is selected
		 * 
		 */
		public function view(owner:*):void
		{
			if(owner == SharedMain.tasker)
				dispatchEvent(new FlackEvent(FlackEvent.CHANGED_LOG, null, FlackEvent.ACTION_SELECTED));
			else
				dispatchEvent(new FlackEvent(FlackEvent.CHANGED_LOG, owner, FlackEvent.ACTION_SELECTED));
		}
	}
}