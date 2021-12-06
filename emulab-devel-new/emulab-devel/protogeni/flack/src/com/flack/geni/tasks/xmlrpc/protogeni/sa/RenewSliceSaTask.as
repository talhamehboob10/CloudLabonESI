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

package com.flack.geni.tasks.xmlrpc.protogeni.sa
{
	import com.flack.geni.resources.docs.GeniCredential;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.utils.DateUtil;
	
	import mx.controls.Alert;
	
	/**
	 * Renews a slice, NOT INCLUDING SLIVERS, until the given date.
	 */
	public final class RenewSliceSaTask extends ProtogeniXmlrpcTask
	{
		public var slice:Slice;
		public var newExpires:Date;
		
		/**
		 * 
		 * @param renewSlice Slice to renew
		 * @param newExpirationDate Desired expiration date/time
		 * 
		 */
		public function RenewSliceSaTask(renewSlice:Slice,
										 newExpirationDate:Date)
		{
			super(
				renewSlice.creator.authority.url,
				"",
				ProtogeniXmlrpcTask.METHOD_RENEWSLICE,
				"Renew " + renewSlice.Name,
				"Renewing slice named " + renewSlice.Name,
				"Renew Slice"
			);
			relatedTo.push(renewSlice);
			slice = renewSlice;
			newExpires = newExpirationDate;
			
			addMessage(
				"Details",
				"Adding " +DateUtil.getTimeBetween(slice.expires, newExpires)+ " for a total of "+DateUtil.getTimeUntil(newExpires)+" until expiration",
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
		}
		
		override protected function createFields():void
		{
			addNamedField("credential", slice.credential.Raw);
			addNamedField("expiration", DateUtil.toRFC3339(newExpires));
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				slice.credential = new GeniCredential(String(data), GeniCredential.TYPE_SLICE, slice.creator.authority);
				slice.expires = slice.credential.Expires;
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					slice
				);
				
				addMessage(
					"Renewed",
					"Renewed, expires in " + DateUtil.getTimeUntil(slice.expires),
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
			{
				Alert.show("Failed to renew slice " + slice.Name);
				faultOnSuccess();
			}
				
		}
	}
}