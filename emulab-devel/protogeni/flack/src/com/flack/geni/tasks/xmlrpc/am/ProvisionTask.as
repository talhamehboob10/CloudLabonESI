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
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.GeniCollaborator;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.resources.virt.VirtualComponent;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.DateUtil;
	
	/**
	 * Provision resources
	 * 
	 * AM v3+
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ProvisionTask extends AmXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		public var manifest:String;
		// hack, afterError should probably be called instead of setting this
		public var success:Boolean = false;
		
		/**
		 * 
		 * @param newSliver Sliver to allocate resources in
		 * @param newRspec RSPEC to send
		 * 
		 */
		public function ProvisionTask(newSliver:AggregateSliver)
		{
			super(
				newSliver.manager.api.url,
				AmXmlrpcTask.METHOD_PROVISION,
				newSliver.manager.api.version,
				"Provision @ " + newSliver.manager.hrn,
				"Provision on aggregate manager " + newSliver.manager.hrn + " for slice named " + newSliver.slice.hrn,
				"Provision"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			
			aggregateSliver = newSliver;
			
			addMessage(
				"Waiting to provision...",
				"Resources will be provisioned at " + aggregateSliver.manager.hrn,
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
		}
		
		override protected function runStart():void
		{
			aggregateSliver.markStaged();
			
			super.runStart();
		}
		
		override protected function createFields():void
		{
			/*
			var sliverUrns:Array = [];
			for(var sliverId:String in aggregateSliver.idsToSlivers)
				sliverUrns.push(sliverId);
			addOrderedField(sliverUrns);
			*/
			addOrderedField([aggregateSliver.slice.id.full]);
			addOrderedField([AmXmlrpcTask.credentialToObject(aggregateSliver.slice.credential, apiVersion)]);
			var options:Object = {};
			var users:Array = [];
			var user:Object = {urn: aggregateSliver.slice.creator.id.full};
			var userKeys:Array = [];
			for each(var userKey:String in aggregateSliver.slice.creator.keys)
			{
				userKeys.push(userKey);
			}
			user.keys = userKeys;
			users.push(user);
			for each(var friend:GeniCollaborator in aggregateSliver.slice.creator.collaborators) {
				var friendObj:Object = {urn: friend.id.full};
				var friendKeys:Array = [];
				for each(var friendKey:String in friend.keys) {
					friendKeys.push(friendKey);
				}
				friendObj.keys = friendKeys;
				users.push(friendObj);
			}
			options["geni_users"] = users;
			addOrderedField(options);
			//V3: geni_best_effort
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
						component.copyFrom(sliver);
				}
				
				parent.add(new ParseRequestManifestTask(aggregateSliver, aggregateSliver.manifest, false, true));
				parent.add(new PerformOperationalActionTask(aggregateSliver, PerformOperationalActionTask.ACTION_START));
				
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