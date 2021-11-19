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
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.tasks.process.StartImportSliceTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.SerialTaskGroup;
	
	/**
	 * Imports a given RSPEC into the slice.
	 * 
	 * 1. Runs a StartImport task to do preliminary checks
	 * 2. Runs Parse tasks at all slivers
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ImportSliceTaskGroup extends SerialTaskGroup
	{
		public var slice:Slice;
		public var rspecString:String;
		public var manager:GeniManager;
		public var overwrite:Boolean;
		
		/**
		 * 
		 * @param importSlice Slice to import RSPEC into
		 * @param importRspec RSPEC to import into slice
		 * @param importManager Manager to default to if not listed
		 * @param allowOverwrite Allow the import to happen into an allocated slice
		 * 
		 */
		public function ImportSliceTaskGroup(importSlice:Slice,
											 importRspec:String,
											 importManager:GeniManager = null,
											 allowOverwrite:Boolean = false)
		{
			super(
				"Import slice",
				"Imports the given RSPEC into the slice"
			);
			relatedTo.push(importSlice);
			slice = importSlice;
			rspecString = importRspec;
			manager = importManager;
			overwrite = allowOverwrite;
		}
		
		override protected function runStart():void
		{
			if(tasks.length == 0)
				add(
					new StartImportSliceTask(
						slice,
						rspecString,
						manager,
						overwrite
					)
				);
			else
				super.runStart();
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			// Remove slivers we don't care about
			for(var i:int = 0; i < slice.aggregateSlivers.length; i++)
			{
				if(!Sliver.isAllocated(slice.aggregateSlivers.collection[i].AllocationState) && slice.aggregateSlivers.collection[i].Nodes.length == 0)
				{
					slice.aggregateSlivers.collection[i].removeFromSlice();
					i--;
				}
			}
			
			addMessage(
				"Finished",
				slice.toString(),
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLICE,
				slice,
				FlackEvent.ACTION_POPULATED
			);
			
			super.afterComplete(addCompletedMessage);
		}
	}
}