/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * Copyright (c) 2011-2012 University of Kentucky.
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

package com.flack.geni.plugins.instools
{
	import com.flack.geni.plugins.Plugin;
	import com.flack.geni.plugins.PluginArea;
	import com.flack.geni.plugins.instools.instasks.InstrumentizeSliceGroupTask;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.tasks.TaskCollection;
	
	import flash.utils.Dictionary;
	
	import mx.controls.Alert;
	
	public class Instools implements Plugin
	{
		public function get Title():String { return "INSTOOLS" };
		public function get Area():PluginArea { return new InstoolsArea() };
		
		public function Instools()
		{
			super();
		}
		
		public function init():void
		{
			SharedMain.sharedDispatcher.addEventListener(FlackEvent.CHANGED_SLICE, slicePopulated);
		}
		
		// Once a slice is populated, figure out if it is instrumentized if there is a MC node present
		public function slicePopulated(e:FlackEvent):void
		{
			if(e.action == FlackEvent.ACTION_POPULATED)
			{
				var slice:Slice = e.changedObject as Slice;
				var hasMCNode:Boolean = false;
				for each(var sliver:AggregateSliver in slice.aggregateSlivers.collection)
				{
					if(doesSliverHaveMc(sliver))
						hasMCNode = true;
				}
				if(hasMCNode)
				{
					instrumentizeSlice(slice, false, 1, false, true);
				}
			}
		}
		
		// XML-RPC Module
		public static const instoolsModule:String = "instools";
		
		// XML-RPC Methods
		public static const getInstoolsVersion:String = "GetINSTOOLSVersion";
		public static const addMCNode:String = "AddMCNode";
		public static const getInstoolsStatus:String = "getInstoolsStatus";
		public static const instrumentize:String = "Instrumentize";
		public static const saveManifest:String = "SaveManifest";
		
		// Global INSTOOLS version
		public static var devel_version:Dictionary = new Dictionary();
		public static var stable_version:Dictionary = new Dictionary();
		
		public static var instrumentizeDetails:Dictionary = new Dictionary();
		
		public static var mcLocation:Dictionary = new Dictionary();
		
		public static function doesSliverHaveMc(sliver:AggregateSliver):Boolean
		{
			if(Sliver.isAllocated(sliver.AllocationState))
			{
				// See if MC node is at manager
				if((sliver.manifest.document.indexOf("MC=\"1\"") != -1) && (sliver.manifest.document.indexOf("mc_type=\"juniper\"") == -1))
					return true;
			}
			return false;
		}
		
		public static function doesSliverHaveJuniperMc(sliver:AggregateSliver):Boolean
		{
			if(Sliver.isAllocated(sliver.AllocationState))
			{
				if(sliver.manifest.document.indexOf("mc_type=\"juniper\"") != -1)
					return true;
			}
			return false;
		}
		
		/**
		 * 
		 * @param slice
		 * @return TRUE on success
		 * 
		 */
		public static function instrumentizeSlice(slice:Slice, creating:Boolean = true, useVersion:Number = 1, useVirtualMCs:Boolean = false, ignoreOtherTasks:Boolean = false, useStableINSTOOLS:Boolean = true):void
		{
			var newDetails:SliceInstoolsDetails = resetSliceDetails(slice, creating, useVersion, useVirtualMCs, useStableINSTOOLS);
			
			if(!ignoreOtherTasks)
			{
				var pendingTasks:TaskCollection = SharedMain.tasker.tasks.NotFinished;
				// Wait for any slice tasks to finish before trying to instrumentize
				if(pendingTasks.All.NotFinished.getRelatedTo(slice).length > 0)
				{
					Alert.show("There are tasks running which involve the slice, please wait for them to finish.");
					return;
				}
			}
			
			if(!creating)
			{
				for each(var sliver:AggregateSliver in slice.aggregateSlivers.collection)
				{
					newDetails.MC_present[sliver.manager.id.full] = doesSliverHaveMc(sliver);
				}
			}
			
			// Do it!
			var instrumentizeTask:InstrumentizeSliceGroupTask = new InstrumentizeSliceGroupTask(newDetails);
			instrumentizeTask.forceRunNow = true;
			SharedMain.tasker.add(instrumentizeTask);
		}
		
		public static function resetSliceDetails(slice:Slice, creating:Boolean = true, useVersion:Number = 1, useVirtualMCs:Boolean = false, useStableINSTOOLS:Boolean = true):SliceInstoolsDetails
		{
			// Clear any cached info for the slice and initalize
			if(instrumentizeDetails[slice.id.full] != null)
				delete instrumentizeDetails[slice.id.full];
			var newDetails:SliceInstoolsDetails = new SliceInstoolsDetails(slice, useVersion, creating, useVirtualMCs, useStableINSTOOLS);
			instrumentizeDetails[slice.id.full] = newDetails;
			return newDetails;
		}
		
		public static function goToPortal(slice:Slice):void
		{
			var sliceDetails:SliceInstoolsDetails = instrumentizeDetails[slice.id.full];
			if(sliceDetails == null)
				Alert.show("Slice either has not been instrumentized or the instrumentation details have not been retrieved. Please click the instrumentize button if you need to instrumentize the slice or if the slice is already instrumentized.");
			else
			{
				if(sliceDetails.hasAnyPortal())
					sliceDetails.goToPortal();
				else
				{
					var pendingTasks:TaskCollection = SharedMain.tasker.tasks.NotFinished.getOfClass(InstrumentizeSliceGroupTask);
					for each(var pendingInstrumentizeTask:InstrumentizeSliceGroupTask in pendingTasks.collection)
					{
						if(pendingInstrumentizeTask.details.slice == slice)
						{
							Alert.show("The slice is currently being instrumentized, please wait for the portal to be created.");
							return;
						}
					}
					Alert.show("The slice doesn't have any portal information yet.");
				}
			}
		}
	}
}