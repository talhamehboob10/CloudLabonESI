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

package com.flack.geni.tasks.xmlrpc.protogeni.ch
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.GeniUser;
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.IdnUrn;
	
	/**
	 * Gets the user's ID and slice authority
	 * 
	 * @author mstrum
	 * 
	 */
	public final class WhoAmIChTask extends ProtogeniXmlrpcTask
	{
		public var user:GeniUser;
		
		/**
		 * 
		 * @param taskUser User we are looking up
		 * 
		 */
		public function WhoAmIChTask(taskUser:GeniUser)
		{
			super(
				GeniMain.geniUniverse.clearinghouse.url,
				ProtogeniXmlrpcTask.MODULE_CH,
				ProtogeniXmlrpcTask.METHOD_WHOAMI,
				"Look me up",
				"Returns information about who I am using the SSL certificate");
			relatedTo.push(taskUser);
			user = taskUser;
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				user.id = new IdnUrn(data.urn);
				var authorityId:String = data.sa_urn;
				for each(var sa:GeniAuthority in GeniMain.geniUniverse.authorities.collection)
				{
					if(sa.id.full == authorityId)
					{
						user.authority = sa;
						break;
					}
				}
				
				if(user.authority == null)
				{
					// XXX afterError? Make sure this doesn't break non-ProtoGENI users
					addMessage(
						"Authority not found",
						authorityId,
						LogMessage.LEVEL_WARNING,
						LogMessage.IMPORTANCE_HIGH
					);
				}
				else
				{
					addMessage(
						"Authority found",
						user.toString(),
						LogMessage.LEVEL_INFO,
						LogMessage.IMPORTANCE_HIGH
					);
				}
				
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