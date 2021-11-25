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
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.tasks.http.PublicListManagersTask;
	import com.flack.geni.tasks.http.PublicListResourcesTask;
	import com.flack.geni.tasks.process.ParseAdvertisementTask;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;

	/**
	 * Discovers all resources advertised publicly
	 * 
	 * 1. PublicListManagersTask
	 * 2. If shouldGetResources: For each manager...
	 *  2a. PublicListResourcesTask
	 *  2b. ParseAdvertisementTask
	 * 
	 * @author mstrum
	 * 
	 */
	public class GetPublicResourcesTaskGroup extends SerialTaskGroup
	{
		private var shouldListManagers:Boolean;
		private var shouldGetResources:Boolean;
		private var parseTasks:SerialTaskGroup;
		
		/**
		 * 
		 * @param listManagers Download the list of managers
		 * @param newShouldGetResources Download each of the managers' public RSPEC
		 * 
		 */
		public function GetPublicResourcesTaskGroup(listManagers:Boolean = true,
													newShouldGetResources:Boolean = true)
		{
			super(
				"Discover resources publicly",
				"Retreives publicly-available GENI resources"
			);
			shouldListManagers = listManagers;
			shouldGetResources = newShouldGetResources;
		}
		
		override protected function runStart():void
		{
			// First run
			if(tasks.length == 0)
			{
				if(shouldListManagers)
					add(new PublicListManagersTask());
				else if(shouldGetResources)
					getResources();
				else
					super.afterComplete();
			}
			super.runStart();
		}
		
		override public function completedTask(task:Task):void
		{
			if(task is PublicListManagersTask && shouldGetResources)
				getResources();
			super.completedTask(task);
		}
		
		private function getResources():void
		{
			if(GeniMain.geniUniverse.managers.length == 0)
				afterComplete();
			else
			{
				for each(var manager:GeniManager in GeniMain.geniUniverse.managers.collection)
					add(new PublicListResourcesTask(manager));
			}
		}
		
		override public function add(task:Task):void
		{
			// put the advertisement parsing in their own serial group
			if(task is ParseAdvertisementTask)
			{
				if(parseTasks == null)
				{
					parseTasks =
						new SerialTaskGroup(
							"Parse RSPECs",
							"Parse RSPECs",
							"",
							null,
							true
						);
					super.add(parseTasks);
				}
				parseTasks.add(task);
			}
			else
				super.add(task);
		}
	}
}