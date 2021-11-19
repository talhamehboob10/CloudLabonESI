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
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.GeniUser;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.utils.NetUtil;
	
	import flash.display.Sprite;
	
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.events.CloseEvent;
	
	/**
	 * Gets the user's public SSH keys
	 * 
	 * @author mstrum
	 * 
	 */
	public class GetUserKeysSaTask extends ProtogeniXmlrpcTask
	{
		public var user:GeniUser;
		public var replaceAll:Boolean;
		
		/**
		 * 
		 * @param newUser User to get keys for
		 * @param shouldReplaceAll Replace the old keys with these, removing any which aren't returned in this call
		 * 
		 */
		public function GetUserKeysSaTask(newUser:GeniUser,
										  shouldReplaceAll:Boolean = true)
		{
			super(
				newUser.authority.url,
				"",
				ProtogeniXmlrpcTask.METHOD_GETKEYS,
				"Get SSH keys",
				"Gets user's public keys"
			);
			relatedTo.push(newUser);
			user = newUser;
			replaceAll = shouldReplaceAll;
		}
		
		override protected function createFields():void
		{
			addNamedField("credential", user.credential.Raw);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == CODE_SUCCESS)
			{
				if(replaceAll)
					user.keys = new Vector.<String>();
				for each(var keyObject:Object in data)
				{
					if(user.keys.indexOf(keyObject.key) == -1)
					{
						addMessage("Public key retrieved", keyObject.key);
						user.keys.push(keyObject.key);
					}
				}
				
				addMessage(
					user.keys.length + " public key(s) retrieved",
					user.keys.length + " public key(s) retrieved",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				if(user.keys.length == 0)
				{
					Alert.show(
						"You don't have any SSH keys, which are required to log into resources.  View online instructions for setting up your SSH keys?",
						"", Alert.YES|Alert.NO, FlexGlobals.topLevelApplication as Sprite,
						function visitSite(e:CloseEvent):void
						{
							if(e.detail == Alert.YES)
								NetUtil.openWebsite(GeniMain.sshKeysSteps);
						}
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