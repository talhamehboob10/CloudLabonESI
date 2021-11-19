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

package com.flack.geni.tasks.groups.slice
{
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.AggregateSliverCollection;
	import com.flack.geni.resources.virt.SliverCollection;
	import com.flack.geni.tasks.process.GenerateRequestManifestTask;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.geni.tasks.xmlrpc.am.AllocateTask;
	import com.flack.geni.tasks.xmlrpc.am.DeleteTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.RedeemTicketCmTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.StartSliverCmTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.UpdateSliverCmTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.xmlrpc.XmlrpcTask;
	import com.flack.shared.utils.NetUtil;
	
	import flash.display.Sprite;
	import flash.events.TextEvent;
	
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.core.mx_internal;
	import mx.events.CloseEvent;
	
	/**
	 * Runs update and starts the slivers
	 * 
	 * @author mstrum
	 * 
	 */
	public final class UpdateAggregateSliversTaskGroup extends SerialTaskGroup
	{
		public var slivers:AggregateSliverCollection;
		public var rspec:Rspec;
		/**
		 * 
		 * @param updateSlivers Slivers to run an update on
		 * @param requestRspec Request RSPEC to send to each manager
		 * 
		 */
		public function UpdateAggregateSliversTaskGroup(updateSlivers:AggregateSliverCollection,
											   requestRspec:Rspec = null)
		{
			super(
				"Update "+updateSlivers.length+" aggregate(s)",
				"Updates existing aggregates with changes"
			);
			slivers = updateSlivers;
			rspec = requestRspec;
			
			for each(var updateSliver:AggregateSliver in slivers.collection)
			{
				if(updateSliver.manager.api.type == ApiDetails.API_GENIAM)
				{
					// V3 only allowed creation and deletion of individual slivers.
					if (updateSliver.manager.api.version > 3)
					{
						// Delete.
						add(new DeleteTask(updateSliver,  updateSliver.DeletedSlivers));
						
						// Allocate.
						var generateNewAllocateRspec:GenerateRequestManifestTask = new GenerateRequestManifestTask(
							updateSliver,
							true, false, false, false, null,
							updateSliver.Components.getByAllocated(false));
						generateNewAllocateRspec.start();
						if(generateNewAllocateRspec.Status != Task.STATUS_SUCCESS)
						{
							afterError(generateNewAllocateRspec.error);
							return;
						}
						add(new AllocateTask(updateSliver, generateNewAllocateRspec.resultRspec));
						
						// Update.
						var updatedSlivers:SliverCollection = updateSliver.Components.getComponentsByUnsubmittedChanges(true).getByAllocated(true);
						if(updatedSlivers.length > 0)
						{
							if (updateSliver.manager.api.version > 4)
							{
							}
							else
							{
								addMessage(
									"Update not supported",
									"AM API v" + updateSliver.manager.api.version + " didn't support updating, existing slivers will remain unchanged.",
									LogMessage.LEVEL_WARNING);
							}
						}
						
					}
					else
					{
						addMessage(
							"Update not supported",
							"AM API v" + updateSliver.manager.api.version + " didn't support updating.",
							LogMessage.LEVEL_WARNING);
					}
				}
				else if(updateSliver.manager.api.type == ApiDetails.API_PROTOGENI)
				{
					if(updateSliver.manager.api.level == ApiDetails.LEVEL_FULL)
					{
						relatedTo.push(updateSliver);
						add(new UpdateSliverCmTask(updateSliver, rspec));
					}
					else
					{
						addMessage(
							"Update not supported",
							"Minimal API doesn't support updating.",
							LogMessage.LEVEL_WARNING);
					}
				}
			}
		}
		
		// Allow user to cancel remaining actions if there is an error anywhere
		override public function erroredTask(task:Task):void
		{
			var msg:String = "";
			if(task is UpdateSliverCmTask)
				msg = " updating aggregate on " + (task as UpdateSliverCmTask).aggregateSliver.manager.hrn;
			else if(task is RedeemTicketCmTask)
				msg = " redeeming ticket on " + (task as RedeemTicketCmTask).aggregateSliver.manager.hrn;
			else if(task is ParseRequestManifestTask)
				msg = " parsing the manifest on " + (task as ParseRequestManifestTask).aggregateSliver.manager.hrn;
			else if(task is StartSliverCmTask)
				msg = " starting the aggregate on " + (task as StartSliverCmTask).aggregateSliver.manager.hrn;
			msg = " starting the sliver on " + (task as StartSliverCmTask).aggregateSliver.manager.hrn;
			var errorLogHtml:String = "";
			if(task is XmlrpcTask)
			{
				errorLogHtml = (task as XmlrpcTask).ErrorLogHtml;
				if(errorLogHtml.length > 0)
					errorLogHtml = "<br><br>" + errorLogHtml;
			}
			var alertMsg:String = "Problem" + msg + ". Continue with the remaining actions?" + errorLogHtml;
			var alert:Alert = Alert.show(
				alertMsg,
				"Continue?",
				Alert.YES|Alert.NO,
				FlexGlobals.topLevelApplication as Sprite,
				userChoice,
				null,
				Alert.YES
			);
			alert.mx_internal::alertForm.mx_internal::textField.htmlText = alertMsg;
			alert.mx_internal::alertForm.mx_internal::textField.addEventListener(
				TextEvent.LINK,
				function clickHandler(e:TextEvent):void {
					NetUtil.openWebsite(e.text);
				});
		}
		
		public function userChoice(event:CloseEvent):void
		{
			if(event.detail == Alert.YES)
			{
				addMessage(
					"User skipped failure",
					"User decided to continue with slice operations even after an update failed",
					LogMessage.LEVEL_WARNING
				);
				runStart();
			}
			else
			{
				addMessage(
					"User canceled remaining",
					"User decided to cancel remaining slice operations after an update failed");
				cancel();
			}
		}
	}
}