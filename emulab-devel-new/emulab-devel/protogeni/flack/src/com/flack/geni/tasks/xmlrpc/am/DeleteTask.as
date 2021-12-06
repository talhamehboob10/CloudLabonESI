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
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.resources.virt.SliverCollection;
	import com.flack.geni.resources.virt.VirtualComponent;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.DateUtil;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Deallocates all resources in the sliver.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class DeleteTask extends AmXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		public var deleteSlivers:SliverCollection = null;
		/**
		 * 
		 * @param deleteSliver Sliver for which to deallocate resources in
		 * 
		 */
		public function DeleteTask(deleteSliver:AggregateSliver, sliversToDelete:SliverCollection = null)
		{
			super(
				deleteSliver.manager.api.url,
				deleteSliver.manager.api.version < 3
					? AmXmlrpcTask.METHOD_DELETESLIVER : AmXmlrpcTask.METHOD_DELETE,
				deleteSliver.manager.api.version,
				"Delete @ " + deleteSliver.manager.hrn,
				"Deleting on aggregate manager " + deleteSliver.manager.hrn + " for slice named " + deleteSliver.slice.Name,
				"Delete"
			);
			relatedTo.push(deleteSliver);
			relatedTo.push(deleteSliver.slice);
			relatedTo.push(deleteSliver.manager);
			
			aggregateSliver = deleteSliver;
			deleteSlivers = sliversToDelete;
		}
		
		override protected function createFields():void
		{
			if(apiVersion > 2)
			{
				var deleteArray:Array = [];
				if(deleteSlivers == null)
					deleteArray.push(aggregateSliver.slice.id.full);
				else
				{
					for each(var deleteSliver:Sliver in deleteSlivers.collection)
						deleteArray.push(deleteSliver.id.full);
				}
				addOrderedField(deleteArray);
			}
			else
				addOrderedField(aggregateSliver.slice.id.full);
			addOrderedField([AmXmlrpcTask.credentialToObject(aggregateSliver.slice.credential, apiVersion)]);
			if(apiVersion > 1)
				addOrderedField({});
			//V3: geni_allocation_state
			//geni_best_effort
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			// Sanity check for AM API 2+
			if(apiVersion > 1)
			{
				if(genicode != AmXmlrpcTask.GENICODE_SUCCESS && genicode != AmXmlrpcTask.GENICODE_SEARCHFAILED)
				{
					faultOnSuccess();
					return;
				}
			}
			
			try
			{
				// Before V3, only the entire aggregate sliver could be deleted.
				if(apiVersion < 3)
				{
					if(data == true || data == 1)
					{
						aggregateSliver.manifest = null;
						aggregateSliver.removeFromSlice();
					}
					else if(data == false || data == 0)
					{
						afterError(
							new TaskError(
								"Received false when trying to delete sliver on " + aggregateSliver.manager.hrn + ".",
								TaskError.CODE_PROBLEM
							)
						);
					}
					else
						throw new Error("Invalid data received");
				}
				else
				{
					// Deleted entire thing
					if(deleteSlivers == null)
					{
						aggregateSliver.manifest = null;
						aggregateSliver.removeFromSlice();
					}
					else
					{
						for each(var geniSliver:Object in data)
						{
							var sliver:Sliver = new Sliver(
								geniSliver.geni_sliver_urn,
								aggregateSliver.slice,
								geniSliver.geni_allocation_status);
							sliver.expires = DateUtil.parseRFC3339(geniSliver.geni_expires);
							aggregateSliver.idsToSlivers[sliver.id.full] = sliver;
							if(geniSliver.geni_error != null)
								sliver.error = geniSliver.geni_error;
							if(sliver.allocationState == Sliver.ALLOCATION_UNALLOCATED)
							{
								aggregateSliver.slice.removeComponentById(sliver.id.full);
							}
							else
							{
								var component:VirtualComponent = aggregateSliver.Components.getComponentById(sliver.id.full);
								if(component != null)
									component.copyFrom(sliver);
							}
						}
					}
				}
				
				addMessage(
					"Removed",
					"Sliver(s) successfully removed",
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
			catch(e:Error)
			{
				afterError(
					new TaskError(
						StringUtil.errorToString(e),
						TaskError.CODE_UNEXPECTED,
						e
					)
				);
			}
		}
	}
}