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
	import com.flack.geni.tasks.process.GenerateRequestManifestTask;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.DateUtil;
	
	import flash.utils.Dictionary;
	
	/**
	 * Allocates resources
	 * 
	 * AM v3+
	 * 
	 * @author mstrum
	 * 
	 */
	public final class UpdateTask extends AmXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		public var request:Rspec;
		public var manifest:String;
		
		/**
		 * 
		 * @param newSliver Sliver to allocate resources in
		 * @param newRspec RSPEC to send
		 * 
		 */
		public function UpdateTask(newSliver:AggregateSliver,
									 newRspec:Rspec = null)
		{
			super(
				newSliver.manager.api.url,
				AmXmlrpcTask.METHOD_UPDATE,
				newSliver.manager.api.version,
				"Update @ " + newSliver.manager.hrn,
				"Updating on aggregate manager " + newSliver.manager.hrn + " for slice named " + newSliver.slice.hrn,
				"Update"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			
			aggregateSliver = newSliver;
			request = newRspec;
			
			addMessage(
				"Waiting to update...",
				"Resources will be updated at " + aggregateSliver.manager.hrn,
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
		}
		
		override protected function runStart():void
		{
			aggregateSliver.markStaged();
			aggregateSliver.manifest = null;
			
			// Generate a rspec if needed
			if(request == null)
			{
				var generateNewRspec:GenerateRequestManifestTask = new GenerateRequestManifestTask(aggregateSliver, true, false, false);
				generateNewRspec.start();
				if(generateNewRspec.Status != Task.STATUS_SUCCESS)
				{
					afterError(generateNewRspec.error);
					return;
				}
				request = generateNewRspec.resultRspec;
				addMessage(
					"Generated request",
					request.document,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
			}
			
			super.runStart();
		}
		
		override protected function createFields():void
		{
			addOrderedField(aggregateSliver.slice.id.full);
			addOrderedField([]);
			addOrderedField([AmXmlrpcTask.credentialToObject(aggregateSliver.slice.credential, apiVersion)]);
			addOrderedField(request.document);
			addOrderedField({});
			//geni_best_effort
			//geni_end_time
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(genicode == AmXmlrpcTask.GENICODE_SUCCESS)
			{
				manifest = data.geni_rspec;
				aggregateSliver.manifest = new Rspec(manifest, null, null, null, Rspec.TYPE_MANIFEST);
				
				addMessage(
					"Manifest received",
					manifest,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				aggregateSliver.idsToSlivers = new Dictionary();
				for each(var geniSliver:Object in data.geni_slivers)
				{
					var sliver:Sliver = new Sliver(
						geniSliver.geni_sliver_urn,
						aggregateSliver.slice,
						geniSliver.geni_allocation_status);
					sliver.expires = DateUtil.parseRFC3339(geniSliver.geni_expires);
					if(geniSliver.geni_error != null)
							sliver.error = geniSliver.geni_error;
					else
						sliver.error = "";
					// next_allocation_status
					aggregateSliver.idsToSlivers[sliver.id.full] = sliver;
					
					var component:VirtualComponent = aggregateSliver.Components.getComponentById(sliver.id.full);
					if(component != null)
						component.copyFrom(sliver);
				}
				
				parent.add(new ParseRequestManifestTask(aggregateSliver, aggregateSliver.manifest, false, true));
				parent.add(new ProvisionTask(aggregateSliver));
				
				super.afterComplete(addCompletedMessage);
			}
			else
			{
				faultOnSuccess();
			}
		}
		
		override protected function afterError(taskError:TaskError):void
		{
			//aggregateSliver.status = AggregateSliver.STATUS_FAILED;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLIVER,
				aggregateSliver,
				FlackEvent.ACTION_STATUS
			);
			
			super.afterError(taskError);
		}
		
		override protected function runCancel():void
		{
			//aggregateSliver.status = AggregateSliver.STATUS_UNKNOWN;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLIVER,
				aggregateSliver,
				FlackEvent.ACTION_STATUS
			);
		}
	}
}