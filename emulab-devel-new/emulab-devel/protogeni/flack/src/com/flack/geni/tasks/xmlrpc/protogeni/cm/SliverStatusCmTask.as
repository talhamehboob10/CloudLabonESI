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

package com.flack.geni.tasks.xmlrpc.protogeni.cm
{
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.resources.virt.VirtualComponent;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.utils.MathUtil;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Finds out the status of all the resources in the sliver.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class SliverStatusCmTask extends ProtogeniXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		public var continueUntilDone:Boolean;
		/**
		 * 
		 * @param newSliver Sliver to get status information for
		 * @param shouldContinueUntilDone Continue until status is finalized?
		 * 
		 */
		public function SliverStatusCmTask(newSliver:AggregateSliver,
										   shouldContinueUntilDone:Boolean = true)
		{
			super(
				newSliver.manager.url,
				ProtogeniXmlrpcTask.MODULE_CM,
				ProtogeniXmlrpcTask.METHOD_SLIVERSTATUS,
				"Get sliver status @ " + newSliver.manager.hrn,
				"Gets the sliver status for component manager " + newSliver.manager.hrn + " on slice named " + newSliver.slice.hrn,
				"Get Sliver Status"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			
			aggregateSliver = newSliver;
			continueUntilDone = shouldContinueUntilDone;
			
			addMessage(
				"Waiting to get status...",
				"Waiting to get sliver status at " + aggregateSliver.manager.hrn,
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
		}
		
		override protected function createFields():void
		{
			addNamedField("slice_urn", aggregateSliver.slice.id.full);
			addNamedField("credentials", [aggregateSliver.slice.credential.Raw]);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				aggregateSliver.AllocationState = Sliver.ALLOCATION_PROVISIONED;
				var sliverOperationalState:String = Sliver.ProtogeniStateStatusToOperationalState(data.state, data.status);
				aggregateSliver.OperationalState = sliverOperationalState;
				for(var sliverId:String in data.details)
				{
					var sliverDetails:Object = data.details[sliverId];
					
					var virtualComponent:VirtualComponent = aggregateSliver.slice.getBySliverId(sliverId);
					if(virtualComponent != null)
					{
						virtualComponent.allocationState = Sliver.ALLOCATION_PROVISIONED;
						virtualComponent.operationalState = Sliver.ProtogeniStateStatusToOperationalState(sliverDetails.state, sliverDetails.status);
						virtualComponent.error = sliverDetails.error;
						aggregateSliver.idsToSlivers[sliverId] = virtualComponent.ClonedSliver;
					}
				}
				
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

				var stateDescription:String = Sliver.describeState(aggregateSliver.AllocationState, aggregateSliver.OperationalState);
				if(!Sliver.isOperationalStateChanging(aggregateSliver.OperationalState))
				{
					addMessage(
						StringUtil.firstToUpper(stateDescription),
						"Status was received and is finished. Current state is " + stateDescription,
						LogMessage.LEVEL_INFO,
						LogMessage.IMPORTANCE_HIGH
					);
					
					super.afterComplete(addCompletedMessage);
				}
				else
				{
					addMessage(
						StringUtil.firstToUpper(stateDescription) + "...",
						"Status was received but is still changing. Current state is " + stateDescription,
						LogMessage.LEVEL_INFO,
						LogMessage.IMPORTANCE_HIGH
					);
					
					// Continue until the status is finished if desired
					if(continueUntilDone)
					{
						delay = MathUtil.randomNumberBetween(20, 60);
						runCleanup();
						start();
					}
					else
						super.afterComplete(addCompletedMessage);
				}
			}
			else
				faultOnSuccess();
		}
	}
}