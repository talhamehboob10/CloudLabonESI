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

package com.flack.emulab.tasks.xmlrpc.node
{
	import com.flack.emulab.tasks.xmlrpc.EmulabXmlrpcTask;
	
	import flash.utils.Dictionary;
	
	public class EmulabNodeCreateImageTask extends EmulabXmlrpcTask
	{
		private var managerUrl:String = "";
		private var node:String;
		private var imagename:String;
		// optional
		private var imageproj:String;
		public function EmulabNodeCreateImageTask(newManagerUrl:String = "https://boss.emulab.net:3069/usr/testbed", newNode:String = "", newImagename:String = "")
		{                                                                   
			super(
				newManagerUrl,
				EmulabXmlrpcTask.MODULE_NODE,
				EmulabXmlrpcTask.METHOD_CREATEIMAGE,
				"Get node availability @ " + newManagerUrl,
				"Getting node availability at " + newManagerUrl,
				"Get node availability"
			);
			managerUrl = newManagerUrl;
			node = newNode;
			imagename = newImagename;
		}
		
		override protected function createFields():void
		{
			addOrderedField(version);
			var args:Dictionary = new Dictionary();
			args["node"] = node;
			args["imagename"] = imagename;
			addOrderedField(args);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == EmulabXmlrpcTask.CODE_SUCCESS)
			{
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}