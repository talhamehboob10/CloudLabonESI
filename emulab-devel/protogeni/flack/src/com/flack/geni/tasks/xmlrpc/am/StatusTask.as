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

package com.flack.geni.tasks.xmlrpc.am
{
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.resources.virt.VirtualComponent;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.DateUtil;
	import com.flack.shared.utils.MathUtil;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Gets the status of the resources in the sliver.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class StatusTask extends AmXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		/**
		 * Keep running until status is final
		 */
		public var continueUntilDone:Boolean;
		/**
		 * 
		 * @param newSliver Sliver to get status for
		 * @param shouldContinueUntilDone Continue running until status is finalized?
		 * 
		 */
		public function StatusTask(newSliver:AggregateSliver,
								   shouldContinueUntilDone:Boolean = true)
		{
			super(
				newSliver.manager.api.url,
				newSliver.manager.api.version < 3
					? AmXmlrpcTask.METHOD_SLIVERSTATUS : AmXmlrpcTask.METHOD_STATUS,
				newSliver.manager.api.version,
				"Get Status @ " + newSliver.manager.hrn,
				"Getting the status for aggregate manager " + newSliver.manager.hrn + " on slice named " + newSliver.slice.Name,
				"Get Status"
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
			if(apiVersion < 3)
			{
				addOrderedField(aggregateSliver.slice.id.full);
			}
			else
			{
				addOrderedField([aggregateSliver.slice.id.full]);
			}
			addOrderedField([AmXmlrpcTask.credentialToObject(aggregateSliver.slice.credential, apiVersion)]);
			if(apiVersion > 1)
				addOrderedField({});
		}

	  private function afterV2(addCompletedMessage : Boolean) : void
	  {
	    aggregateSliver.AllocationState = Sliver.ALLOCATION_PROVISIONED;
	    var globalStatus:String = data.geni_status;
					
	    if (data.pg_status && data.geni_status == 'unknown' && (data.pg_status == 'changing' || data.pg_status == 'mixed')) {
	      globalStatus = 'configuring';
	    }
	    aggregateSliver.OperationalState = Sliver.GeniStatusToOperationalState(globalStatus);
	    addMessage(
	      "Global status: " + globalStatus,
	      "pg_status: " + String(data.pg_status) + ", geni_status: " + String(data.geni_status) + ', conversion: ' + String(Sliver.GeniStatusToOperationalState(globalStatus)) + ', aggregateSliver: ' + String(aggregateSliver.OperationalState),
	      LogMessage.LEVEL_INFO,
	      LogMessage.IMPORTANCE_HIGH
	    );
	    aggregateSliver.id = new IdnUrn(data.geni_urn);
	    for each(var componentObject:Object in data.geni_resources)
	    {
	      var componentSliver:Sliver = new Sliver(
		componentObject.geni_urn,
		aggregateSliver.slice,
		Sliver.ALLOCATION_PROVISIONED);
	      if(componentObject.geni_status != null)
	      {
		var sliverStatus : String = componentObject.geni_status;
		if (sliverStatus == 'changing')
		{
		  sliverStatus = 'configuring';
		}
		componentSliver.operationalState = Sliver.GeniStatusToOperationalState(sliverStatus);
		addMessage(
		  "Sliver status: " + componentSliver.operationalState,
		  "geni_status: " + componentObject.geni_status,
		  LogMessage.LEVEL_INFO,
		  LogMessage.IMPORTANCE_HIGH
		);
	      }
	      //V4: geni_next_allocation_status
	      if(componentObject.geni_error != null)
		componentSliver.error = componentObject.geni_error;
	      else
		componentSliver.error = "";
	      aggregateSliver.idsToSlivers[componentSliver.id.full] = componentSliver;
			
	      var virtualComponent:VirtualComponent = aggregateSliver.Components.getComponentById(componentSliver.id.full);
	      if(virtualComponent != null)
	      {
		virtualComponent.copyFrom(componentSliver);
	      }
	      else
	      {
		addMessage(
		  "Node not found",
		  "Node with sliver id " + componentSliver.id.full + " wasn't found in the sliver! " +
		  "This may indicate that the manager failed to include the sliver id in the manifest.",
		  LogMessage.LEVEL_FAIL,
		  LogMessage.IMPORTANCE_HIGH,
		  true
		);
	      }
	    }
	  }

	  private function afterV3(addCompletedMessage:Boolean) : void
	  {
	    for each(var geniSliver:Object in data.geni_slivers)
	    {
	      var sliver:Sliver = new Sliver(
		geniSliver.geni_sliver_urn,
		aggregateSliver.slice,
		geniSliver.geni_allocation_status,
		geniSliver.geni_operational_status);
	      sliver.expires = DateUtil.parseRFC3339(geniSliver.geni_expires);
	      if(geniSliver.geni_error != null)
		sliver.error = geniSliver.geni_error;
	      aggregateSliver.idsToSlivers[sliver.id.full] = sliver;
	      
	      var component:VirtualComponent = aggregateSliver.Components.getComponentById(sliver.id.full);
	      if(component != null)
	      {
		component.copyFrom(sliver);
	      }
	      else
	      {
		addMessage(
		  "Node not found",
		  "Node with sliver id " + sliver.id.full + " wasn't found in the sliver! " +
		  "This may indicate that the manager failed to include the sliver id in the manifest.",
		  LogMessage.LEVEL_FAIL,
		  LogMessage.IMPORTANCE_HIGH,
		  true
		);
	      }
	    }
	  }
		
	  override protected function afterComplete(addCompletedMessage:Boolean=false):void
	  {
	    // Sanity check for AM API 2+
	    if(apiVersion > 1)
	    {
	      if(genicode != AmXmlrpcTask.GENICODE_SUCCESS)
	      {
		faultOnSuccess();
		return;
	      }
	    }
	    
	    try
	    {
	      if(apiVersion < 3)
	      {
		afterV2(addCompletedMessage);
	      }
	      else
	      {
		afterV3(addCompletedMessage);
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
		    
	      var aggregateStatus:String = Sliver.describeState(aggregateSliver.AllocationState, aggregateSliver.OperationalState);
	      if(!Sliver.isOperationalStateChanging(aggregateSliver.OperationalState))
	      {
		addMessage(
		  StringUtil.firstToUpper(aggregateStatus),
		  "Status was received and is finished. Current status is " + aggregateStatus,
		  LogMessage.LEVEL_INFO,
		  LogMessage.IMPORTANCE_HIGH
		);
		parent.add(new DescribeTask(aggregateSliver));
		super.afterComplete(addCompletedMessage);
	      }
	      else
	      {
		addMessage(
		  StringUtil.firstToUpper(aggregateStatus) + "...",
		  "Status was received but is still changing. Current status is " + aggregateStatus,
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
	    catch(e:Error)
	    {
	      afterError(
		new TaskError(
		  StringUtil.errorToString(e),
		  TaskError.CODE_UNEXPECTED,
		  e
		)
	      );
	    }
	  }
	}
}
