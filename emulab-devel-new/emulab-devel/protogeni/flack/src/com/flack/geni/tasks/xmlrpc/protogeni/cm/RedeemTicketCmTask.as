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
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.DateUtil;
	
	import mx.controls.Alert;
	
	/**
	 * Redeems an issued ticket. Only supported on the FULL API
	 * 
	 * @author mstrum
	 * 
	 */
	public final class RedeemTicketCmTask extends ProtogeniXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		// hack, afterError should probably be called instead of setting this
		public var success:Boolean = false;
		
		/**
		 * 
		 * @param newSliver Sliver to redeem ticket for
		 * 
		 */
		public function RedeemTicketCmTask(newSliver:AggregateSliver)
		{
			super(
				newSliver.manager.url,
				ProtogeniXmlrpcTask.MODULE_CM,
				ProtogeniXmlrpcTask.METHOD_REDEEMTICKET,
				"Redeem ticket @ " + newSliver.manager.hrn,
				"Updates ticket for sliver on " + newSliver.manager.hrn + " for slice named " + newSliver.slice.Name,
				"Redeem Ticket"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			aggregateSliver = newSliver;
		}
		
		override protected function runStart():void
		{
			if(aggregateSliver.manager.api.level == ApiDetails.LEVEL_MINIMAL)
			{
				afterError(
					new TaskError(
						"Full API not supported",
						TaskError.CODE_PROBLEM
					)
				);
				return;
			}
			
			aggregateSliver.markStaged();
			aggregateSliver.manifest = null;
			
			super.runStart();
		}
		
		override protected function createFields():void
		{
			addNamedField("slice_urn", aggregateSliver.slice.id.full);
			if(aggregateSliver.credential != null && aggregateSliver.credential.Raw.length > 0)
				addNamedField("credentials", [aggregateSliver.credential.Raw]);
			else
				addNamedField("credentials", [aggregateSliver.slice.credential.Raw]);
			addNamedField("ticket", aggregateSliver.ticket.document);
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
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				success = true;
				aggregateSliver.credential = new GeniCredential(
					data[0],
					GeniCredential.TYPE_SLIVER,
					aggregateSliver.manager);
				aggregateSliver.id = aggregateSliver.credential.getIdWithType(IdnUrn.TYPE_SLIVER);
				aggregateSliver.Expires = aggregateSliver.credential.Expires;
				aggregateSliver.manifest = new Rspec(data[1], null, null, null, Rspec.TYPE_MANIFEST);
				aggregateSliver.AllocationState = Sliver.ALLOCATION_PROVISIONED;
				
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
				parent.add(new StartSliverCmTask(aggregateSliver));
			}
			else
			{
				addMessage(
					"Problem redeeming",
					"There was a problem redeeming the ticket. The ticket will now be released.",
					LogMessage.LEVEL_FAIL,
					LogMessage.IMPORTANCE_HIGH
				);
				Alert.show("Problem redeeming ticket at " + aggregateSliver.manager.hrn);
				
				// Release the ticket so the user can get another
				parent.add(new ReleaseTicketCmTask(aggregateSliver));
				// Re-get the sliver to represent how it currently is
				parent.add(new GetSliverCmTask(aggregateSliver));
			}
				
			super.afterComplete(addCompletedMessage);
		}
	}
}