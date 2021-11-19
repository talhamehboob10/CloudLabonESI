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

package com.flack.geni.tasks.groups.slice
{
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.SliceCollection;
	import com.flack.geni.tasks.groups.GetResourcesTaskGroup;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	
	import flash.display.Sprite;
	
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.events.CloseEvent;
	
	/**
	 * Gets all information about an existing slice
	 * 
	 * 1. If resolveSlice and user has authority...
	 *  1a. ResolveSliceSaTask
	 *  1b. GetSliceCredentialSaTask
	 * 2. For each manager...
	 *    If queryAllManagers, or in slice.reportedManagers, or non-ProtoGENI, or no slice authority
	 *  2a. ListSliverResourcesTask/GetSliverCmTask
	 *  2b. ParseManifestTask
	 * 
	 * @author mstrum
	 * 
	 */
	public final class GetSlicesTaskGroup extends SerialTaskGroup
	{
		public var slices:SliceCollection;
		public var queryAllManagers : Boolean;
		
		/**
		 * 
		 * @param taskSlice Slice to get everything for
		 * @param shouldResolveSlice Resolve the slice?
		 * @param shouldQueryAllManagers Query all managers? Needed if resources exist at non-ProtoGENI managers.
		 * 
		 */
		public function GetSlicesTaskGroup(newSlices:SliceCollection,
						shouldQueryAllManagers : Boolean = false)
		{
			super(
				"Get slices",
				"Gets the slices for the user"
			);
			queryAllManagers = shouldQueryAllManagers;
			slices = newSlices;
		}

		override protected function runStart():void
		{
			if(tasks.length == 0)
			{
				add(new ResolveSlicesTaskGroup(slices));
				add(new DescribeSlicesTaskGroup(slices, queryAllManagers));
			}

			super.runStart();
		}
		
		override public function completedTask(task:Task):void
		{
			if(task is ResolveSlicesTaskGroup)
			{
				// Find out if there are managers with resources which aren't loaded.
				var queryUnloadedManagers:GeniManagerCollection = new GeniManagerCollection();
				for each(var slice:Slice in slices.collection)
				{
					for each(var manager:GeniManager in slice.reportedManagers.collection)
					{
						if(manager.Status != FlackManager.STATUS_VALID)
						{
							if(!queryUnloadedManagers.contains(manager))
								queryUnloadedManagers.add(manager);
						}
					}
				}
				
				// If there are managers with resources which aren't loaded, prompt the user.
				if(queryUnloadedManagers.length > 0)
				{
					var managersString:String = "";
					for each(var unloadedManager:GeniManager in queryUnloadedManagers.collection)
					{
						managersString += "\t" + unloadedManager.hrn + "\n";
					}
					Alert.show(
						"The following managers are reported to have resources but aren't loaded. Should Flack attempt to load them?\n" +
						managersString,
						"Attempt to load managers?",
						Alert.YES|Alert.NO,
						FlexGlobals.topLevelApplication as Sprite,
						function afterChoice(event:CloseEvent):void
						{
							if(event.detail == Alert.YES)
								add(new GetResourcesTaskGroup(false, true, queryUnloadedManagers));
							else
								add(new DescribeSlicesTaskGroup(slices, queryAllManagers));
						},
						null,
						Alert.YES
					);
					return;
				}
			}
			else if(task is GetResourcesTaskGroup)
			{
				add(new DescribeSlicesTaskGroup(slices, queryAllManagers));
			}
			super.completedTask(task);
		}
	}
}