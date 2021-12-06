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
	import com.flack.geni.resources.GeniUser;
	import com.flack.geni.resources.docs.GeniCredential;
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.IdnUrn;
	
	/**
	 * Gets the user's credential.
	 * 
	 * @author mstrum
	 * 
	 */
	public class GetUserCredentialSaTask extends ProtogeniXmlrpcTask
	{
		public var user:GeniUser;
		public var authority:GeniAuthority;
		
		/**
		 * 
		 * @param newUser User for which we are getting the credential for
		 * @param newAuthority Authority where we want to get the credential from
		 * 
		 */
		public function GetUserCredentialSaTask(newUser:GeniUser, newAuthority:GeniAuthority)
		{
			super(
				newAuthority.url,
				"",
				ProtogeniXmlrpcTask.METHOD_GETCREDENTIAL,
				"Get user credential",
				"Gets the user's credential to perform authenticated actions with"
			);
			authority = newAuthority;
			relatedTo.push(newUser);
			user = newUser;
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == CODE_SUCCESS)
			{
				var userCredential:GeniCredential = new GeniCredential(String(data), GeniCredential.TYPE_USER, user.authority);
				if(user.authority == authority)
				{
					user.credential = userCredential;
					user.id = user.credential.getIdWithType(IdnUrn.TYPE_USER);
				}
				authority.userCredential = userCredential;
				
				addMessage(
					"Retrieved",
					userCredential.Raw,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_USER,
					user
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}