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
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.tasks.xmlrpc.am.ListImagesTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.ListImagesCmTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.display.windows.TextInputWindow;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.ParallelTaskGroup;

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
	public class ListImagesTaskGroup extends ParallelTaskGroup
	{
		private var creatorId:String;
		
		/**
		 * 
		 * @param listManagers Download the list of managers
		 * @param newShouldGetResources Download each of the managers' public RSPEC
		 * 
		 */
		public function ListImagesTaskGroup(newCreatorId:String = "")
		{
			super(
				"List user disk images",
				"Lists all disk images created by a user on all managers"
			);
			creatorId = newCreatorId;
		}
		
		override protected function runStart():void
		{
			if(tasks.length == 0)
			{
				if(creatorId.length == 0)
					promptName();
				else
					listImages();
			}
		}
		
		public function listImages():void
		{
			var managers:GeniManagerCollection = GeniMain.geniUniverse.managers.Valid;
			for each(var manager:GeniManager in managers.collection)
			{
				if(manager.type == GeniManager.TYPE_PROTOGENI)
				{
					if(manager.api.type == ApiDetails.API_PROTOGENI)
						add(new ListImagesCmTask(creatorId, manager));
					else if(manager.api.type == ApiDetails.API_GENIAM)
						add(new ListImagesTask(creatorId, manager));
				}
			}
			super.runStart();
		}
		
		public function promptName():void
		{
			var promptForNameWindow:TextInputWindow = new TextInputWindow();
			promptForNameWindow.onSuccess = userChoseName;
			promptForNameWindow.onCancel = cancel;
			promptForNameWindow.showWindow();
			promptForNameWindow.title = "Please enter the user urn to list their disk images";
			promptForNameWindow.Text = GeniMain.geniUniverse.user.id.full;
		}
		
		public function userChoseName(newName:String):void
		{
			creatorId = newName;
			listImages();
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_USERDISKIMAGES,
				creatorId
			);
			
			super.afterComplete(addCompletedMessage);
		}
	}
}