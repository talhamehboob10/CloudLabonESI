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
	import com.flack.emulab.EmulabMain;
	import com.flack.emulab.resources.physical.PhysicalNode;
	import com.flack.emulab.tasks.xmlrpc.EmulabXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.docs.RspecVersion;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.tasks.TaskError;
	
	import flash.utils.Dictionary;
	
	public class EmulabNodeGetListTask extends EmulabXmlrpcTask
	{
		// proj, class, type, nodes
		private var nodeType:String = "";
		private var nodeClass:String = "";
		// "https://boss.emulab.net:3069/usr/testbed"
		public function EmulabNodeGetListTask(newType:String = "", newClass:String="")
		{
			super(
				EmulabMain.manager.api.url,
				EmulabXmlrpcTask.MODULE_NODE,
				EmulabXmlrpcTask.METHOD_GETLIST,
				"List nodes @ " + EmulabMain.manager.url,
				"Getting list of nodes at " + EmulabMain.manager.url,
				"List nodes"
			);
			nodeType = newType;
			nodeClass = newClass;
			relatedTo.push(EmulabMain.manager);
			EmulabMain.manager.Status = FlackManager.STATUS_INPROGRESS;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGER,
				EmulabMain.manager
			);
		}
		
		override protected function createFields():void
		{
			addOrderedField(version);
			var args:Dictionary = new Dictionary();
			if(nodeType.length > 0)
				args["type"] = nodeType;
			if(nodeClass.length > 0)
				args["class"] = nodeClass;
			addOrderedField(args);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == EmulabXmlrpcTask.CODE_SUCCESS)
			{
				EmulabMain.manager.advertisement = new Rspec(output, new RspecVersion(RspecVersion.TYPE_EMULAB, EmulabMain.manager.api.version), new Date(), new Date(), Rspec.TYPE_ADVERTISEMENT);
				
				for(var nodeId:String in data)
				{
					var nodeObject:Object = data[nodeId];
					
					var node:PhysicalNode = new PhysicalNode(EmulabMain.manager, nodeId);
					node.available = nodeObject.free;
					if(nodeObject.type != null)
						node.hardwareType = nodeObject.type;
					if(nodeObject.auxtypes != null)
					{
						var auxTypes:Array = nodeObject.auxtypes.split(',');
						for each(var auxType:String in auxTypes)
							node.auxTypes.push(auxType);
					}
					EmulabMain.manager.nodes.add(node);
				}
				
				EmulabMain.manager.Status = FlackManager.STATUS_VALID;
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_MANAGER,
					EmulabMain.manager,
					FlackEvent.ACTION_STATUS
				);
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_MANAGER,
					EmulabMain.manager,
					FlackEvent.ACTION_POPULATED
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
		
		override protected function afterError(taskError:TaskError):void
		{
			EmulabMain.manager.Status = FlackManager.STATUS_FAILED;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGER,
				EmulabMain.manager,
				FlackEvent.ACTION_STATUS
			);
			
			super.afterError(taskError);
		}
		
		override protected function runCancel():void
		{
			EmulabMain.manager.Status = FlackManager.STATUS_FAILED;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGER,
				EmulabMain.manager,
				FlackEvent.ACTION_STATUS
			);
		}
	}
}