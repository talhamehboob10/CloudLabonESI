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
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.SerialTaskGroup;
	
	import flash.utils.Dictionary;
	
	/**
	 * Clears the slice and reloads based on the previouslly retrieved manifests.
	 * If changes are made to a slice which need to be undone, call this.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class RevertToManifestsTaskGroup extends SerialTaskGroup
	{
		public var idToStatus:Dictionary;
		public var idToState:Dictionary;
		public var slice:Slice;
		/**
		 * 
		 * @param newSlice Slice to revert back to the last allocated state
		 * 
		 */
		public function RevertToManifestsTaskGroup(newSlice:Slice)
		{
			super(
				"Revert to manifests",
				"Reverts the slice to the recieved manifests"
			);
			slice = newSlice;
			
			slice.removeComponents();
			slice.clearStatus();
			for(var i:int = 0; i < slice.aggregateSlivers.length; i++)
			{
				var sliver:AggregateSliver = slice.aggregateSlivers.collection[i];
				if(Sliver.isAllocated(sliver.AllocationState))
					add(new ParseRequestManifestTask(sliver, sliver.manifest, false, true));
				else
				{
					slice.aggregateSlivers.remove(sliver);
					i--;
				}
			}
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			// Try to revert if there's anything to revert
			slice.resetStatus();
			
			addMessage(
				"Reverted",
				slice.Name + " has been reverted to its state when it was created. ",
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