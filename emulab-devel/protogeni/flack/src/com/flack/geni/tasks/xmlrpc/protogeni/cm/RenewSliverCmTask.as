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
	import com.flack.shared.utils.DateUtil;
	
	import mx.controls.Alert;
	
	/**
	 * Renews the sliver until the given date
	 * 
	 * @author mstrum
	 * 
	 */
	public final class RenewSliverCmTask extends ProtogeniXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		public var newExpires:Date;
		
		/**
		 * 
		 * @param renewSliver Sliver to renew
		 * @param newExpirationDate Desired expiration date
		 * 
		 */
		public function RenewSliverCmTask(renewSliver:AggregateSliver,
										  newExpirationDate:Date)
		{
			super(
				renewSliver.manager.url,
				ProtogeniXmlrpcTask.MODULE_CM,
				ProtogeniXmlrpcTask.METHOD_RENEWSLICE,
				"Renew sliver @ " + renewSliver.manager.hrn,
				"Renewing sliver on " + renewSliver.manager.hrn + " on slice named " + renewSliver.slice.hrn,
				"Renew Sliver"
			);
			relatedTo.push(renewSliver);
			relatedTo.push(renewSliver.slice);
			relatedTo.push(renewSliver.manager);
			aggregateSliver = renewSliver;
			newExpires = newExpirationDate;
		}
		
		override protected function createFields():void
		{
			addNamedField("slice_urn", aggregateSliver.slice.id.full);
			addNamedField("expiration", DateUtil.toRFC3339(newExpires));
			addNamedField("credentials", [aggregateSliver.slice.credential.Raw]);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
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
					"Renewed, expires in " + DateUtil.getTimeUntil(aggregateSliver.EarliestExpiration),
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
			{
				Alert.show("Failed to renew sliver @ " + aggregateSliver.manager.hrn);
				faultOnSuccess();
			}
		}
	}
}
