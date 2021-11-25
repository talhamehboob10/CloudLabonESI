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

package com.flack.emulab.tasks.xmlrpc.user
{
	import com.flack.emulab.EmulabMain;
	import com.flack.emulab.tasks.xmlrpc.EmulabXmlrpcTask;
	
	import flash.utils.Dictionary;
	
	public class EmulabUserMembershipTask extends EmulabXmlrpcTask
	{
		private const PERMISSION_READINFO:String = "readinfo";
		private const PERMISSION_CREATEEXPT:String = "createexpt";
		private const PERMISSION_MAKEGROUP:String = "makegroup";
		private const PERMISSION_MAKEOSID:String = "makeosid";
		private const PERMISSION_MAKEIMAGEID:String = "makeimageid";
		
		// optional
		private var permission:String;
		public function EmulabUserMembershipTask(newPermission:String = "")
		{
			super(
				EmulabMain.manager.api.url,
				EmulabXmlrpcTask.MODULE_USER,
				EmulabXmlrpcTask.METHOD_MEMBERSHIP,
				"Get number of used nodes @ " + EmulabMain.manager.api.url,
				"Getting node availability at " + EmulabMain.manager.api.url,
				"# Nodes Used"
			);
			permission = newPermission;
			relatedTo.push(EmulabMain.user);
			relatedTo.push(EmulabMain.manager);
		}
		
		override protected function createFields():void
		{
			addOrderedField(version);
			var args:Dictionary = new Dictionary();
			if(permission.length > 0)
				args["permission"] = permission;
			addOrderedField(args);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == EmulabXmlrpcTask.CODE_SUCCESS)
			{/*
				for(var projName:String in data)
				{
					var subGroup:String = data[projName];
					var subId:String = IdnUrn.makeFrom(projName+":"+subGroup, "subgroup", "subgroup").full;
					
					if(user.subAuthorities.getById(subId) == null)
					{
						var newAuthority:EmulabAuthority = new EmulabAuthority(subId, user.authority.url, false, user.authority as EmulabAuthority);
						user.subAuthorities.add(newAuthority);
					}
					
				}
				
				SharedMain.sharedDispatcher.dispatchUserChanged();
				*/
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}