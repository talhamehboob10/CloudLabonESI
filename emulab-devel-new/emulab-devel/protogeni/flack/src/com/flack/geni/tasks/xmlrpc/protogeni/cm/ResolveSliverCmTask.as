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
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.tasks.TaskError;
	
	/**
	 * Retrieves the manifest for the sliver and adds a task to the parent to parse the manifest
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ResolveSliverCmTask extends ProtogeniXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		
		/**
		 * 
		 * @param newSliver Sliver to resolve
		 * 
		 */
		public function ResolveSliverCmTask(newSliver:AggregateSliver)
		{
			super(
				newSliver.manager.url,
				ProtogeniXmlrpcTask.MODULE_CM,
				ProtogeniXmlrpcTask.METHOD_RESOLVE,
				"Resolve sliver @ " + newSliver.manager.hrn,
				"Resolves sliver on component manager named " + newSliver.manager.hrn + " on slice named " + newSliver.slice.Name,
				"Resolve Sliver"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			aggregateSliver = newSliver;
		}
		
		override protected function createFields():void
		{
			addNamedField("urn", aggregateSliver.id.full);
			addNamedField("credentials", [aggregateSliver.credential.Raw]);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				addMessage(
					"Manifest received",
					data.manifest,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH);
				
				aggregateSliver.manifest = new Rspec(data.manifest,null, null,null, Rspec.TYPE_MANIFEST);
				parent.add(new ParseRequestManifestTask(aggregateSliver, aggregateSliver.manifest, false, true));
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
		
		override protected function afterError(taskError:TaskError):void
		{
			//sliver.status = AggregateSliver.STATUS_FAILED;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLIVER,
				aggregateSliver,
				FlackEvent.ACTION_STATUS
			);
			
			super.afterError(taskError);
		}
		
		override protected function runCancel():void
		{
			//sliver.status = AggregateSliver.STATUS_UNKNOWN;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLIVER,
				aggregateSliver,
				FlackEvent.ACTION_STATUS
			);
		}
	}
}