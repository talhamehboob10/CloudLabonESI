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

package com.flack.geni.tasks.xmlrpc.am
{
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	
	/**
	 * Deallocates all resources in the sliver.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class CancelTask extends AmXmlrpcTask
	{
		public var sliver:AggregateSliver;
		/**
		 * 
		 * @param deleteSliver Sliver for which to deallocate resources in
		 * 
		 */
		public function CancelTask(deleteSliver:AggregateSliver)
		{
			super(
				deleteSliver.manager.api.url,
				AmXmlrpcTask.METHOD_CANCEL,
				deleteSliver.manager.api.version,
				"Cancel @ " + deleteSliver.manager.hrn,
				"Canceling on aggregate manager " + deleteSliver.manager.hrn + " for slice named " + deleteSliver.slice.Name,
				"Cancel"
			);
			relatedTo.push(deleteSliver);
			relatedTo.push(deleteSliver.slice);
			relatedTo.push(deleteSliver.manager);
			sliver = deleteSliver;
		}
		
		override protected function createFields():void
		{
			addOrderedField([sliver.slice.id.full]);
			addOrderedField([AmXmlrpcTask.credentialToObject(sliver.slice.credential, apiVersion)]);
			addOrderedField({});
			//V3: geni_allocation_state
			//geni_best_effort
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(genicode == AmXmlrpcTask.GENICODE_SUCCESS)
			{
				sliver.manifest = null;
				sliver.removeFromSlice();
				//V3: parse structs
				
				addMessage(
					"Removed",
					"Slice successfully removed",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLIVER,
					sliver,
					FlackEvent.ACTION_REMOVED
				);
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					sliver.slice,
					FlackEvent.ACTION_REMOVING
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
			{
				faultOnSuccess();
			}
		}
	}
}