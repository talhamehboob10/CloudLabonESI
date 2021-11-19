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
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.GetUserCredentialSaTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.GetUserKeysSaTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.RegisterSliceSaTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.RenewSliceSaTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.ResolveSliceSaTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.ResolveUserSaTask;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskEvent;
	
	public class AuthorityTestGroup extends TestTaskGroup
	{
		private var authority:GeniAuthority;
		public function AuthorityTestGroup(testAuthority:GeniAuthority)
		{
			super(
				"Test authority functions",
				"Test authority functions"
			);
		}
		
		override protected function startTest():void
		{
			addTest(
				"Get user credential",
				new GetUserCredentialSaTask(S, authority),
				gotCredential
			);
		}
		
		public function gotCredential(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				
				addTest(
					"Submit slice",
					new ResolveUserSaTask(),
					resolvedUser
				);
			}
		}
		
		public function resolvedUser(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				
				addTest(
					"Submit slice",
					new GetUserKeysSaTask(),
					gotKeys
				);
			}
		}
		
		public function gotKeys(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				
				addTest(
					"Submit slice",
					new RegisterSliceSaTask(),
					registeredSlice
				);
			}
		}
		
		public function registeredSlice(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				
				addTest(
					"Submit slice",
					new ResolveSliceSaTask(),
					resolvedSlice
				);
			}
		}
		
		public function resolvedSlice(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				
				addTest(
					"Submit slice",
					new RenewSliceSaTask(),
					renewedSlice
				);
			}
		}
		
		public function renewedSlice(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				testsSucceeded();
			}
		}
	}
}