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
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.TaskError;
	
	/**
	 * Stops all resources in the sliver.  Only supported by the FULL API
	 * 
	 * @author mstrum
	 * 
	 */
	public final class StopSliverCmTask extends ProtogeniXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		
		/**
		 * 
		 * @param newSliver Sliver to stop resources in
		 * 
		 */
		public function StopSliverCmTask(newSliver:AggregateSliver)
		{
			super(
				newSliver.manager.url,
				ProtogeniXmlrpcTask.MODULE_CM,
				ProtogeniXmlrpcTask.METHOD_STOPSLIVER,
				"Stop sliver @ " + newSliver.manager.hrn,
				"Stops sliver on " + newSliver.manager.hrn + " for slice named " + newSliver.slice.Name,
				"Stop Sliver"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			aggregateSliver = newSliver;
		}
		
		override protected function createFields():void
		{
			addNamedField("slice_urn", aggregateSliver.slice.id.full);
			addNamedField("credentials", [aggregateSliver.slice.credential.Raw]);
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
			super.runStart();
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				addMessage(
					"Stopped",
					"Sliver was stopped",
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}