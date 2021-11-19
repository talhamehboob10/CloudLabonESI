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
	
	/**
	 * Gets the slice credential for access to the slice.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class GetSliceCredentialSaTask extends ProtogeniXmlrpcTask
	{
		public var slice:Slice;
		
		/**
		 * 
		 * @param taskSlice Slice for which we are getting the credential for
		 * 
		 */
		public function GetSliceCredentialSaTask(taskSlice:Slice)
		{
			super(
				taskSlice.authority.url,
				"",
				ProtogeniXmlrpcTask.METHOD_GETCREDENTIAL,
				"Get slice credential for " + taskSlice.Name,
				"Getting the slice credential for " + taskSlice.Name,
				"Get slice credential"
			);
			relatedTo.push(taskSlice);
			slice = taskSlice;
		}
		
		override protected function createFields():void
		{
			addNamedField("credential", slice.authority.userCredential.Raw);
			addNamedField("urn", slice.id.full);
			addNamedField("type", "Slice");
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				slice.credential = new GeniCredential(data, GeniCredential.TYPE_SLICE, slice.authority);
				slice.expires = slice.credential.Expires;
				
				addMessage(
					"Expires in " + DateUtil.getTimeUntil(slice.expires),
					"Expires in " + DateUtil.getTimeUntil(slice.expires),
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				addMessage(
					"Received",
					"Credential retreived for slice.",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					slice
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}