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
	import com.flack.geni.tasks.process.GenerateRequestManifestTask;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Allocates resources for the sliver using the given RSPEC, usually generated for the entire slice.
	 * 
	 * Deprecated in AMv3, use Allocate+Provision instead.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class CreateSliverTask extends AmXmlrpcTask
	{
		public var sliver:AggregateSliver;
		public var request:Rspec;
		
		/**
		 * 
		 * @param newSliver Sliver to allocate resources in
		 * @param newRspec RSPEC to send
		 * 
		 */
		public function CreateSliverTask(newSliver:AggregateSliver,
										 newRspec:Rspec = null)
		{
			super(
				newSliver.manager.api.url,
				AmXmlrpcTask.METHOD_CREATESLIVER,
				newSliver.manager.api.version,
				"Create @ " + newSliver.manager.hrn,
				"Creating on aggregate manager " + newSliver.manager.hrn + " for slice named " + newSliver.slice.hrn,
				"Create"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			
			sliver = newSliver;
			request = newRspec;
			
			addMessage(
				"Waiting to create...",
				"Resources will be created at " + sliver.manager.hrn,
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
		}
		
		override protected function runStart():void
		{
			sliver.markStaged();
			sliver.manifest = null;
			
			// Generate a rspec if needed
			if(request == null)
			{
				var generateNewRspec:GenerateRequestManifestTask = new GenerateRequestManifestTask(sliver, true, false, false);
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
			addOrderedField(sliver.slice.id.full);
			addOrderedField([sliver.slice.credential.Raw]);
			addOrderedField(request.document);
			var users:Array = [];
			var user:Object = {urn: sliver.slice.creator.id.full};
			var userKeys:Array = [];
			for each(var key:String in sliver.slice.creator.keys)
			{
				userKeys.push(key);
			}
			user.keys = userKeys;
			users.push(user);
			for each(var friend:GeniCollaborator in sliver.slice.creator.collaborators) {
				var friendObj:Object = {urn: friend.id.full};
				var friendKeys:Array = [];
				for each(var friendKey:String in friend.keys) {
					friendKeys.push(friendKey);
				}
				friendObj.keys = friendKeys;
				users.push(friendObj);
			}
			addOrderedField(users);
			if(apiVersion > 1)
				addOrderedField({});
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
				sliver.manifest = new Rspec(data,null,null,null, Rspec.TYPE_MANIFEST);
				
				addMessage(
					"Manifest received",
					data,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				parent.add(new ParseRequestManifestTask(sliver, sliver.manifest, false, true));
				
				super.afterComplete(addCompletedMessage);
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
		
		override protected function afterError(taskError:TaskError):void
		{
			//sliver.status = AggregateSliver.STATUS_FAILED;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLIVER,
				sliver,
				FlackEvent.ACTION_STATUS
			);
			
			super.afterError(taskError);
		}
		
		override protected function runCancel():void
		{
			//sliver.status = AggregateSliver.STATUS_UNKNOWN;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLIVER,
				sliver,
				FlackEvent.ACTION_STATUS
			);
		}
	}
}