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

package com.flack.emulab.tasks.xmlrpc.osid
{
	import com.flack.emulab.EmulabMain;
	import com.flack.emulab.resources.physical.Osid;
	import com.flack.emulab.resources.physical.OsidCollection;
	import com.flack.emulab.tasks.xmlrpc.EmulabXmlrpcTask;
	
	import flash.events.Event;
	import flash.utils.Dictionary;
	
	import mx.core.FlexGlobals;
	
	public class EmulabOsidGetListTask extends EmulabXmlrpcTask
	{
		public function EmulabOsidGetListTask()
		{
			super(
				EmulabMain.manager.api.url,
				EmulabXmlrpcTask.MODULE_OSID,
				EmulabXmlrpcTask.METHOD_GETLIST,
				"Get OSID List @ " + EmulabMain.manager.api.url,
				"Getting OSID list on manager at " + EmulabMain.manager.api.url,
				"Get OSID List"
			);
		}
		
		override protected function createFields():void
		{
			addOrderedField(version);
			var args:Dictionary = new Dictionary();
			addOrderedField(args);
		}
		
		private var myIndex:int;
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == EmulabXmlrpcTask.CODE_SUCCESS)
			{
				EmulabMain.manager.osids = new OsidCollection();
				for(var osidString:String in data)
				{
					var osidObject:Object = data[osidString];
					var newOsid:Osid = new Osid(
						osidString,
						osidObject.OS,
						osidObject.version,
						osidObject.description,
						osidObject.pid,
						osidObject.creator,
						osidObject.created
					);
					EmulabMain.manager.osids.add(newOsid);
				}
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}