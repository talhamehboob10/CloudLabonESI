/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * Copyright (c) 2011-2012 University of Kentucky.
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

package com.flack.geni.plugins.instools.instasks
{
	import com.flack.geni.plugins.instools.Instools;
	import com.flack.geni.plugins.instools.SliceInstoolsDetails;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.StartSliverCmTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.MathUtil;
	
	import mx.controls.Alert;
	
	public final class PollInstoolsStatusTask extends ProtogeniXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		public var details:SliceInstoolsDetails;
		
		public function PollInstoolsStatusTask(newSliver:AggregateSliver, useDetails:SliceInstoolsDetails)
		{
			super(
				newSliver.manager.url,
				Instools.instoolsModule + "/" + useDetails.apiVersion.toFixed(1),
				Instools.getInstoolsStatus,
				"Poll Instools Status @ " + newSliver.manager.hrn,
				"Getting the sliver status on " + newSliver.manager.hrn + " on slice named " + newSliver.slice.Name,
				"Poll INSTOOLS Status"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.manager);
			relatedTo.push(newSliver.slice);
			aggregateSliver = newSliver;
			details = useDetails;
		}
		
		override protected function createFields():void
		{
			addNamedField("urn", aggregateSliver.slice.id.full);
			addNamedField("INSTOOLS_VERSION", details.useStableINSTOOLS ? Instools.stable_version[aggregateSliver.manager.id.full] : Instools.devel_version[aggregateSliver.manager.id.full]);
			//addNamedField("INSTOOLS_VERSION",Instools.devel_version[sliver.manager.id.full]);
			addNamedField("credentials", [aggregateSliver.slice.credential.Raw]);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code ==  ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				details.instools_status[aggregateSliver.manager.id.full] = String(data.status);
				var status:String = String(data.status);
				switch(status) {
					case "INSTRUMENTIZE_COMPLETE":		//instrumentize is finished, experiment is ready, etc.
						details.portal_url[aggregateSliver.manager.id.full] = String(data.portal_url);
						//HACK
						aggregateSliver.OperationalState = Sliver.OPERATIONAL_READY;
						broadcastStatus();
						var msg:String = details.creating ? "Instrumentizing complete!" : "INSTOOLS running!";
						addMessage(
							msg,
							msg,
							LogMessage.LEVEL_INFO,
							LogMessage.IMPORTANCE_HIGH
						);
						super.afterComplete(addCompletedMessage);
						return;
					case "INSTALLATION_COMPLETE":		//MC has finished the startup scripts
						addMessage(
							"Instrumentize scripts installed...",
							"Instrumentize scripts installed...",
							LogMessage.LEVEL_INFO,
							LogMessage.IMPORTANCE_HIGH
						);
						if (details.started_instrumentize[aggregateSliver.manager.id.full] != "1")
						{
							addMessage(
								"Instrumentizing...",
								"Instrumentizing...",
								LogMessage.LEVEL_INFO,
								LogMessage.IMPORTANCE_HIGH
							);
							parent.add(new InstrumentizeTask(aggregateSliver, details));
							details.started_instrumentize[aggregateSliver.manager.id.full] = "1";
						}
						break;
					case "MC_NOT_STARTED":				//MC has been added, but not started
						addMessage(
							"MC not started...",
							"MC not started...",
							LogMessage.LEVEL_INFO,
							LogMessage.IMPORTANCE_HIGH
						);
						if (details.started_MC[aggregateSliver.manager.id.full] != "1")
						{
							addMessage(
								"Starting...",
								"Starting...",
								LogMessage.LEVEL_INFO,
								LogMessage.IMPORTANCE_HIGH
							);
							parent.add(new StartSliverCmTask(aggregateSliver));
							details.started_MC[aggregateSliver.manager.id.full] = "1";
						}
						break;
					case "INSTRUMENTIZE_IN_PROGRESS":	//the instools server has started instrumentizing the nodes
						addMessage(
							"Instrumentize in progress...",
							"Instrumentize in progress...",
							LogMessage.LEVEL_INFO,
							LogMessage.IMPORTANCE_HIGH
						);
						break;
					case "INSTALLATION_IN_PROGRESS":	//MC is running it's startup scripts
						addMessage(
							"Instrumentize installing...",
							"Instrumentize installing...",
							LogMessage.LEVEL_INFO,
							LogMessage.IMPORTANCE_HIGH
						);
						break;
					case "MC_NOT_PRESENT":				//The addMC/updatesliver calls haven't finished 
						addMessage(
							"MC Node not added yet...",
							"MC Node not added yet...",
							LogMessage.LEVEL_WARNING,
							LogMessage.IMPORTANCE_HIGH
						);
						break;
					case "MC_UNSUPPORTED_OS":
						addMessage(
							"Unsupported OS! Maybe not booted...",
							"Unsupported OS! Maybe not booted...",
							LogMessage.LEVEL_WARNING,
							LogMessage.IMPORTANCE_HIGH
						);
						break;
					default:
						//HACK
						aggregateSliver.OperationalState = Sliver.OPERATIONAL_FAILED;
						addMessage(
							status + "!",
							status + "!"
						);
						broadcastStatus();
						Alert.show("Unrecognized INSTOOLS status: " + status);
						afterError(
							new TaskError(
								"Unrecognized INSTOOLS status: " + status,
								TaskError.FAULT,
								status
							)
						);
						return;
				}
				
				// At this point, still changing and polling...
				//HACK
				aggregateSliver.OperationalState = Sliver.OPERATIONAL_CONFIGURING;
				broadcastStatus();
				delay = MathUtil.randomNumberBetween(20, 60);
				runCleanup();
				start();
			}
			else
				faultOnSuccess();
		}
		
		override protected function afterError(taskError:TaskError):void
		{
			failed();
			super.afterError(taskError);
		}
		
		override protected function runCancel():void
		{
			failed();
		}
		
		private function broadcastStatus():void
		{
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLIVER,
				aggregateSliver,
				FlackEvent.ACTION_STATUS
			);
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLICE,
				aggregateSliver.slice,
				FlackEvent.ACTION_STATUS
			);
		}
		
		public function failed():void
		{
			addMessage(
				"Poll INSTOOLS status failed",
				"Poll INSTOOLS status failed",
				LogMessage.LEVEL_FAIL,
				LogMessage.IMPORTANCE_HIGH
			);
			Alert.show(
				"Failed to poll INSTOOLS status on " + aggregateSliver.manager.hrn + ". ",
				"Problem polling INSTOOLS status"
			);
		}
	}
}