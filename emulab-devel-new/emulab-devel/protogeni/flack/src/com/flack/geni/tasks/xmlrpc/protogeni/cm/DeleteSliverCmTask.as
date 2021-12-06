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

package com.flack.geni.tasks.xmlrpc.protogeni.cm
{
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	
	/**
	 * Releases all resources allocated to the sliver.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class DeleteSliverCmTask extends ProtogeniXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		
		/**
		 * 
		 * @param deleteSliver Sliver to deallocate resources for
		 * 
		 */
		public function DeleteSliverCmTask(deleteSliver:AggregateSliver)
		{
			super(
				deleteSliver.manager.url,
				ProtogeniXmlrpcTask.MODULE_CM,
				ProtogeniXmlrpcTask.METHOD_DELETESLICE,
				"Delete sliver @ " + deleteSliver.manager.hrn,
				"Deleting sliver on component manager " + deleteSliver.manager.hrn + " for slice named " + deleteSliver.slice.Name,
				"Delete Sliver"
			);
			relatedTo.push(deleteSliver);
			relatedTo.push(deleteSliver.slice);
			relatedTo.push(deleteSliver.manager);
			aggregateSliver = deleteSliver;
		}
		
		override protected function createFields():void
		{
			addNamedField("slice_urn", aggregateSliver.slice.id.full);
			addNamedField("credentials", [aggregateSliver.slice.credential.Raw]);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(code == ProtogeniXmlrpcTask.CODE_SUCCESS
				|| code == ProtogeniXmlrpcTask.CODE_SEARCHFAILED)
			{
				aggregateSliver.manifest = null;
				aggregateSliver.removeFromSlice();
				//sliver.UnsubmittedChanges = false;
				
				addMessage(
					"Removed",
					"Slice successfully removed",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLIVER,
					aggregateSliver,
					FlackEvent.ACTION_REMOVED
				);
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					aggregateSliver.slice,
					FlackEvent.ACTION_REMOVING
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}