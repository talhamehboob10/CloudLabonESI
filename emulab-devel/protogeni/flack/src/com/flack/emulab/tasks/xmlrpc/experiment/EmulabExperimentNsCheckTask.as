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

package com.flack.emulab.tasks.xmlrpc.experiment
{
	import com.flack.emulab.tasks.xmlrpc.EmulabXmlrpcTask;
	
	import flash.utils.Dictionary;
	
	public class EmulabExperimentNsCheckTask extends EmulabXmlrpcTask
	{
		private var managerUrl:String = "";
		public function EmulabExperimentNsCheckTask(newManagerUrl:String = "https://boss.emulab.net:3069/usr/testbed")
		{                                                                   
			super(
				newManagerUrl,
				EmulabXmlrpcTask.MODULE_EXPERIMENT,
				EmulabXmlrpcTask.METHOD_NSCHECK,
				"Get number of used nodes @ " + newManagerUrl,
				"Getting node availability at " + newManagerUrl,
				"# Nodes Used"
			);
			managerUrl = newManagerUrl;
		}
		
		override protected function createFields():void
		{
			addOrderedField(version);
			var args:Dictionary = new Dictionary();
			//args["nsfilestr"] = ??;
			addOrderedField(args);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == EmulabXmlrpcTask.CODE_SUCCESS)
			{
				//The return code is RESPONSE_SUCCESS or RESPONSE_ERROR.
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}