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
	import com.flack.geni.resources.virt.VirtualComponent;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.DateUtil;
	import com.flack.shared.utils.StringUtil;
	
	import mx.controls.Alert;
	
	/**
	 * Renews the sliver until the given date.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class RenewTask extends AmXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		public var newExpires:Date;
		//V3: geni_best_effort
		
		/**
		 * 
		 * @param renewSliver Sliver to renew
		 * @param newExpirationDate Desired expiration date
		 * 
		 */
		public function RenewTask(renewSliver:AggregateSliver,
								  newExpirationDate:Date)
		{
			super(
				renewSliver.manager.api.url,
				renewSliver.manager.api.version < 3
					? AmXmlrpcTask.METHOD_RENEWSLIVER : AmXmlrpcTask.METHOD_RENEW,
				renewSliver.manager.api.version,
				"Renew @ " + renewSliver.manager.hrn,
				"Renewing on " + renewSliver.manager.hrn + " on slice named " + renewSliver.slice.hrn,
				"Renew"
			);
			relatedTo.push(renewSliver);
			relatedTo.push(renewSliver.slice);
			relatedTo.push(renewSliver.manager);
			aggregateSliver = renewSliver;
			newExpires = newExpirationDate;
		}
		
		override protected function createFields():void
		{
			if(apiVersion < 3)
				addOrderedField(aggregateSliver.slice.id.full);
			else
				addOrderedField([aggregateSliver.slice.id.full]);
			addOrderedField([AmXmlrpcTask.credentialToObject(aggregateSliver.slice.credential, apiVersion)]);
			addOrderedField(DateUtil.toRFC3339(newExpires));
			if(apiVersion > 1)
				addOrderedField({});
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			// Sanity check for AM API 2+
			if(apiVersion > 1)
			{
				if(genicode != AmXmlrpcTask.GENICODE_SUCCESS)
				{
					faultOnSuccess();
					return;
				}
			}
			
			try
			{
				if(apiVersion < 3)
				{
					if(data == true)
					{
						aggregateSliver.Expires = newExpires;
						
						SharedMain.sharedDispatcher.dispatchChanged(
							FlackEvent.CHANGED_SLIVER,
							aggregateSliver
						);
						SharedMain.sharedDispatcher.dispatchChanged(
							FlackEvent.CHANGED_SLICE,
							aggregateSliver.slice
						);
						
						addMessage(
							"Renewed",
							"Renewed, sliver expires in " + DateUtil.getTimeUntil(aggregateSliver.EarliestExpiration),
							LogMessage.LEVEL_INFO,
							LogMessage.IMPORTANCE_HIGH
						);
						
						super.afterComplete(addCompletedMessage);
					}
					else if(data == false)
					{
						Alert.show("Failed to renew sliver @ " + aggregateSliver.manager.hrn);
						afterError(
							new TaskError(
								"Renew failed",
								TaskError.CODE_PROBLEM
							)
						);
					}
					else
					{
						afterError(
							new TaskError(
								"Renew failed. Received incorrect data",
								TaskError.CODE_UNEXPECTED
							)
						);
					}
				}
				else
				{
					for each(var geniSliver:Object in data)
					{
						var sliver:Sliver = new Sliver(
							geniSliver.geni_sliver_urn,
							sliver.slice,
							geniSliver.geni_allocation_status,
							geniSliver.geni_operational_status);
						sliver.expires = DateUtil.parseRFC3339(geniSliver.geni_expires);
						if(geniSliver.geni_error != null)
							sliver.error = geniSliver.geni_error;
						//V3: geni_resource_status
						//V4: geni_next_allocation_status
						aggregateSliver.idsToSlivers[sliver.id.full] = sliver;
						
						var component:VirtualComponent = aggregateSliver.Components.getComponentById(sliver.id.full);
						if(component != null)
							component.copyFrom(sliver);
					}
				}
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
