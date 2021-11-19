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
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.geni.tasks.xmlrpc.am.AllocateTask;
	import com.flack.geni.tasks.xmlrpc.am.CreateSliverTask;
	import com.flack.geni.tasks.xmlrpc.am.PerformOperationalActionTask;
	import com.flack.geni.tasks.xmlrpc.am.ProvisionTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.CreateSliverCmTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.GetTicketCmTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.RedeemTicketCmTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.StartSliverCmTask;
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
	 * Allocate resources for the first time at a manager for a slice.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class CreateAggregateSliversTaskGroup extends SerialTaskGroup
	{
		public var slivers:AggregateSliverCollection;
		public var rspec:Rspec;
		/**
		 * 
		 * @param createSlivers Slivers to allocate resources at
		 * @param requestRspec RSPEC to send to each manager
		 * @param askToContinueOnFailure Ask the user to continue on failures? ... Not used???
		 * 
		 */
		public function CreateAggregateSliversTaskGroup(createSlivers:AggregateSliverCollection,
											   requestRspec:Rspec = null,
											   askToContinueOnFailure:Boolean = true)
		{
			super(
				"Add "+createSlivers.length+" resource(s)",
				"Add new resources"
			);
			slivers = createSlivers;
			rspec = requestRspec;
			
			for each(var newSliver:AggregateSliver in slivers.collection)
			{
				if(newSliver.manager.api.type == ApiDetails.API_GENIAM)
				{
					if(newSliver.manager.api.version < 3)
						add(new CreateSliverTask(newSliver, rspec));
					else
						add(new AllocateTask(newSliver, rspec));
				}
				else
				{
					if(newSliver.manager.api.level == ApiDetails.LEVEL_MINIMAL)
						add(new CreateSliverCmTask(newSliver, rspec));
					else
						add(new GetTicketCmTask(newSliver, rspec));
				}
			}
		}
		
		// Allow user to cancel remaining actions if there is an error anywhere
		override public function erroredTask(task:Task):void
		{
			var msg:String = "";
			if(task is CreateSliverCmTask)
				msg = " creating on " + (task as CreateSliverCmTask).aggregateSliver.manager.hrn;
			else if(task is CreateSliverTask)
				msg = " creating on " + (task as CreateSliverTask).sliver.manager.hrn;
			else if(task is ParseRequestManifestTask)
				msg = " parsing the manifest on " + (task as ParseRequestManifestTask).aggregateSliver.manager.hrn;
			else if(task is GetTicketCmTask)
				msg = " updating on " + (task as GetTicketCmTask).aggregateSliver.manager.hrn;
			else if(task is RedeemTicketCmTask)
				msg = " redeeming ticket on " + (task as RedeemTicketCmTask).aggregateSliver.manager.hrn;
			else if(task is StartSliverCmTask)
				msg = " starting on " + (task as StartSliverCmTask).aggregateSliver.manager.hrn;
			else if(task is PerformOperationalActionTask)
				msg = " starting on " + (task as PerformOperationalActionTask).aggregateSliver.manager.hrn;
			if(task is AllocateTask)
				msg = " allocating on " + (task as AllocateTask).aggregateSliver.manager.hrn;
			if(task is ProvisionTask)
				msg = " provisioning on " + (task as ProvisionTask).aggregateSliver.manager.hrn;
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
					"User decided to continue with slice operations even after a create failed",
					LogMessage.LEVEL_WARNING,
					LogMessage.IMPORTANCE_HIGH
				);
				runStart();
			}
			else
			{
				addMessage(
					"User canceled remaining",
					"User decided to cancel remaining slice operations after a create failed",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				cancel();
			}
		}
	}
}