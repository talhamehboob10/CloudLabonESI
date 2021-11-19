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

package com.flack.geni.tasks.groups
{
	import com.flack.geni.resources.GeniUser;
	import com.flack.geni.tasks.xmlrpc.protogeni.ch.WhoAmIChTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.GetUserCredentialSaTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.GetUserKeysSaTask;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	
	/**
	 * Gets the user credential and ssh keys. Detects user authority if not set.
	 * 
	 * 1. If no authority assigned: WhoAmIChTask
	 * 2. If no user credential or replaceOldInformation:
	 *  2a. GetUserCredentialSaTask
	 *  2b. GetUserKeysSaTask
	 * 
	 * @author mstrum
	 * 
	 */
	public class InitializeUserTaskGroup extends SerialTaskGroup
	{
		public var user:GeniUser;
		public var replaceOldInformation:Boolean;
		
		/**
		 * 
		 * @param taskUser User to initialize
		 * @param taskReplaceOldInformation Replace keys and credential?
		 * 
		 */
		public function InitializeUserTaskGroup(taskUser:GeniUser,
												taskReplaceOldInformation:Boolean = false)
		{
			super(
				"Initialize user",
				"Gets initial info about the user"
			);
			relatedTo.push(taskUser);
			forceSerial = true;
			
			user = taskUser;
			replaceOldInformation = taskReplaceOldInformation;
		}
		
		override protected function runStart():void
		{
			// First run
			if(tasks.length == 0)
			{
				if(user.authority == null)
					add(new WhoAmIChTask(user)); // XXX see what happens with a pl user...
				else
					getUser();
			}
			super.runStart();
		}
		
		override public function completedTask(task:Task):void
		{
			if(task is WhoAmIChTask)
				getUser();
			super.completedTask(task);
		}
		
		public function getUser():void
		{
			if(user.authority != null && (user.credential == null || replaceOldInformation))
			{
				add(new GetUserCredentialSaTask(user, user.authority));
				add(new GetUserKeysSaTask(user));
			}
			else
				afterComplete();
		}
	}
}