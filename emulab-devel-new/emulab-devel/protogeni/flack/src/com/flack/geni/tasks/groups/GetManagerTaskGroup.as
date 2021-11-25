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
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.tasks.process.ParseAdvertisementTask;
	import com.flack.geni.tasks.xmlrpc.am.GetVersionTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.GetVersionCmTask;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	
	/**
	 * Gets version information and resources for a manager
	 * 
	 * @author mstrum
	 * 
	 */
	public final class GetManagerTaskGroup extends SerialTaskGroup
	{
		public var manager:GeniManager;
		
		/**
		 * 
		 * @param taskManager Manager to get
		 * 
		 */
		public function GetManagerTaskGroup(taskManager:GeniManager)
		{
			super(
				"Get " + taskManager.hrn,
				"Retreives resources for " + taskManager.id.full
			);
			manager = taskManager;
		}
		
		override protected function runStart():void
		{
			// First run
			if(tasks.length == 0)
			{
				if(manager.api.type == ApiDetails.API_GENIAM)
					add(new GetVersionTask(manager));
				else if(manager.api.type == ApiDetails.API_PROTOGENI)
					add(new GetVersionCmTask(manager));
			}
			super.runStart();
		}
		
		override public function add(task:Task):void
		{
			if(task is ParseAdvertisementTask)
			{
				// If part of a larger operation, add it to that operation to parse serially
				if(parent is GetResourcesTaskGroup)
				{
					parent.add(task);
					return;
				}
			}
			super.add(task);
		}
	}
}