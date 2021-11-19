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
	import com.flack.geni.GeniCache;
	import com.flack.geni.GeniMain;
	import com.flack.geni.display.windows.ChooseManagersToWatchWindow;
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.tasks.process.ParseAdvertisementTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.ch.ListComponentsChTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.tasks.ParallelTaskGroup;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	
	import flash.utils.Dictionary;

	/**
	 * Gets the list of managers and/or lists their resources
	 * 
	 * 1. If shouldListManagers: ListComponentsChTask
	 * 2. If shouldGetResources: For each manager....
	 *  2a. GetVersionTask/GetVersionCmTask
	 * 
	 * @author mstrum
	 * 
	 */
	public class GetResourcesTaskGroup extends ParallelTaskGroup
	{
		private var shouldListManagers:Boolean;
		private var shouldGetResources:Boolean;
		private var parseTasks:SerialTaskGroup;
		private var limitToManagers:GeniManagerCollection;
		
		/**
		 * 
		 * @param listManagers Get the list of managers
		 * @param newShouldGetResources Get each of the managers' resources
		 * 
		 */
		public function GetResourcesTaskGroup(listManagers:Boolean = true,
											  newShouldGetResources:Boolean = true,
											  newLimitToManagers:GeniManagerCollection = null)
		{
			super(
				"Get resources",
				"Retreives GENI resources"
			);
			limitRunningCount = 5;
			forceSerial = true;
			shouldListManagers = listManagers;
			shouldGetResources = newShouldGetResources;
			limitToManagers = newLimitToManagers;
		}
		
		override protected function runStart():void
		{
			if((GeniMain.geniUniverse.user.authority == null ||
				GeniMain.geniUniverse.user.authority.type != GeniAuthority.TYPE_EMULAB) &&
				GeniMain.geniUniverse.user.credential == null)
			{
				afterError(
					new TaskError(
						"No user certificate!",
						TaskError.CODE_PROBLEM
					)
				);
				return;
			}
			// First run
			if(tasks.length == 0)
			{
				if(shouldListManagers)
					add(new ListComponentsChTask(GeniMain.geniUniverse.user));
				else if(shouldGetResources)
					tryGetResources();
				else
					afterComplete();
			}
			super.runStart();
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_UNIVERSE,
				null,
				FlackEvent.ACTION_POPULATED
			);
			super.afterComplete(addCompletedMessage);
		}
		
		override public function completedTask(task:Task):void
		{
			if(task is ListComponentsChTask && shouldGetResources)
			{
				if(tryGetResources())
					return;
			}
			super.completedTask(task);
		}
		
		// if true, waiting for user
		private function tryGetResources():Boolean
		{
			if(GeniMain.geniUniverse.managers.length == 0)
				afterComplete();
			else if(limitToManagers != null)
			{
				getResources(limitToManagers);
			}
			else
			{
				if(GeniMain.loadAllManagersWithoutAsking)
				{
					getResources(GeniMain.geniUniverse.managers);
				}
				else if(GeniCache.shouldAskWhichManagersToWatch() &&
					GeniMain.geniUniverse.user.authority.type != GeniAuthority.TYPE_EMULAB)
				{
					var askWindow:ChooseManagersToWatchWindow = new ChooseManagersToWatchWindow();
					askWindow.callAfter = getResources;
					askWindow.showWindow(true, true);
					return true;
				} else {
					var managersToWatch:Dictionary = GeniCache.getManagersToWatch();
					var managers:GeniManagerCollection = GeniMain.geniUniverse.managers.Clone;
					for(var managerId:String in managersToWatch)
					{
						if(managersToWatch[managerId] == false)
							managers.remove(managers.getById(managerId));
					}
					getResources(managers);
				}
			}
			return false;
		}
		
		private function getResources(managers:GeniManagerCollection):void
		{
			for each(var manager:GeniManager in managers.collection)
				add(new GetManagerTaskGroup(manager));
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
							"Parse advertisements",
							"Parses the advertised RSPECs one after the other",
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
		
		override public function erroredTask(task:Task):void
		{
			if(task is ListComponentsChTask)
			{
				cancelRemainingTasks();
				add(new GetPublicResourcesTaskGroup());
				start();
			}
			else
				super.erroredTask(task);
		}
	}
}