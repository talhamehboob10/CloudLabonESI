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
	import com.flack.geni.resources.GeniCollaborator;
	import com.flack.geni.resources.docs.GeniCredential;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.tasks.process.GenerateRequestManifestTask;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.utils.DateUtil;
	
	/**
	 * Creates a sliver based on the given RSPEC, usually generated for the entire slice.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class CreateSliverCmTask extends ProtogeniXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		public var request:Rspec;
		
		/**
		 * 
		 * @param newSliver Sliver to allocate resources in
		 * @param useRspec RSPEC used to allocate resources
		 * 
		 */
		public function CreateSliverCmTask(newSliver:AggregateSliver,
										   useRspec:Rspec = null)
		{
			super(
				newSliver.manager.url,
				ProtogeniXmlrpcTask.MODULE_CM,
				ProtogeniXmlrpcTask.METHOD_CREATESLIVER,
				"Create sliver @ " + newSliver.manager.hrn,
				"Creating sliver on component manager " + newSliver.manager.hrn + " for slice named " + newSliver.slice.hrn,
				"Create Sliver"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			aggregateSliver = newSliver;
			
			request = useRspec;
			
			addMessage(
				"Waiting to create...",
				"A sliver will be created at " + aggregateSliver.manager.hrn,
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
			addNamedField("slice_urn", aggregateSliver.slice.id.full);
			addNamedField("rspec", request.document);
			var users:Array = [];
			var user:Object = {urn: aggregateSliver.slice.creator.id.full, login: aggregateSliver.slice.creator.id.name};
			var userKeys:Array = [];
			for each(var key:String in aggregateSliver.slice.creator.keys) {
				userKeys.push({type:"ssh", key:key}); // XXX type
			}
			user.keys = userKeys;
			users.push(user);
			for each(var friend:GeniCollaborator in aggregateSliver.slice.creator.collaborators) {
				var friendObj:Object = {login: friend.id.name};
				var friendKeys:Array = [];
				for each(var friendKey:String in friend.keys) {
					friendKeys.push({type:"ssh", key:friendKey}); // XXX type
				}
				friendObj.keys = friendKeys;
				users.push(friendObj);
			}
			addNamedField("keys", users);
			addNamedField("credentials", [aggregateSliver.slice.credential.Raw]);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				aggregateSliver.credential = new GeniCredential(data[0], GeniCredential.TYPE_SLIVER, aggregateSliver.manager);
				aggregateSliver.id = aggregateSliver.credential.getIdWithType(IdnUrn.TYPE_SLIVER);
				aggregateSliver.Expires = aggregateSliver.credential.Expires;
				aggregateSliver.manifest = new Rspec(data[1],null,null,null, Rspec.TYPE_MANIFEST);
				
				addMessage(
					"Credential received",
					data[0],
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				addMessage(
					"Manifest received",
					data[1],
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				addMessage(
					"Expires in " + DateUtil.getTimeUntil(aggregateSliver.EarliestExpiration),
					"Expires in " + DateUtil.getTimeUntil(aggregateSliver.EarliestExpiration),
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				parent.add(new ParseRequestManifestTask(aggregateSliver, aggregateSliver.manifest, false, true));
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}