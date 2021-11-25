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
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.tasks.xmlrpc.am.DeleteTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.DeleteSliverCmTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.ParallelTaskGroup;
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
	 * Deletes slivers, allowing user to cancel remaining slice operations on error
	 * 
	 * @author mstrum
	 * 
	 */
	public final class DeleteAggregateSliversTaskGroup extends ParallelTaskGroup
	{
		public var slivers:AggregateSliverCollection;
		public var askOnError:Boolean;
		public var waitingForUser:Boolean = false;
		public var ignoreUncreated:Boolean;
		/**
		 * 
		 * @param deleteSlivers Slivers to delete
		 * @param askUserOnError Ask user to continue if an error occurs?
		 * @param shouldIgnoreUncreated Skip slivers which don't have manifests
		 * 
		 */
		public function DeleteAggregateSliversTaskGroup(deleteSlivers:AggregateSliverCollection, askUserOnError:Boolean = true, shouldIgnoreUncreated:Boolean = true)
		{
			super(
				"Release"+(deleteSlivers == null ? "" : " "+deleteSlivers.length)+" aggregate sliver(s)",
				"Release resources not used anymore"
			);
			slivers = deleteSlivers;
			askOnError = askUserOnError;
			ignoreUncreated = shouldIgnoreUncreated;
			
			for(var i:int = 0; i < slivers.length; i++)
			{
				var deleteSliver:AggregateSliver = slivers.collection[i];
				if(!ignoreUncreated || Sliver.isAllocated(deleteSliver.AllocationState))
				{
					if(deleteSliver.manager.api.type == ApiDetails.API_GENIAM)
						add(new DeleteTask(deleteSliver));
					else
						add(new DeleteSliverCmTask(deleteSliver));
				}
				else
				{
					deleteSliver.removeFromSlice();
					i--;
				}
			}
		}
		
		override public function completeIfFinished(tryStarting:Boolean = true):void
		{
			if(waitingForUser)
				return;
			
			super.completeIfFinished(tryStarting);
		}
		
		// Allow user to cancel remaining actions if there is an error anywhere
		override public function erroredTask(task:Task):void
		{
			// Already asked and waiting...
			if(waitingForUser)
				return;
			
			// Don't prompt user
			if(!askOnError)
			{
				super.erroredTask(task);
				return;
			}
				
			waitingForUser = true;
			var name:String;
			if(task is DeleteTask)
				name = (task as DeleteTask).aggregateSliver.manager.hrn;
			else
				name = (task as DeleteSliverCmTask).aggregateSliver.manager.hrn;
			var errorLogHtml:String = "";
			if(task is XmlrpcTask)
			{
				errorLogHtml = (task as XmlrpcTask).ErrorLogHtml;
				if(errorLogHtml.length > 0)
					errorLogHtml = "<br><br>" + errorLogHtml;
			}
			var alertMsg:String = "Problem deleting sliver on " + name + ". Continue with the remaining actions?" + errorLogHtml;
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
			waitingForUser = false;
			if(event.detail == Alert.YES)
			{
				addMessage(
					"User skipped failure",
					"User decided to continue with slice operations even after a delete failed",
					LogMessage.LEVEL_WARNING,
					LogMessage.IMPORTANCE_HIGH
				);
				completeIfFinished();
			}
			else
			{
				addMessage(
					"User canceled remaining",
					"User decided to cancel remaining slice operations after a delete failed",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				cancel();
			}
		}
	}
}