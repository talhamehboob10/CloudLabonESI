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
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.docs.RspecVersion;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.CompressUtil;
	import com.flack.shared.utils.DateUtil;
	import com.flack.shared.utils.StringUtil;
	
	import flash.utils.Dictionary;
	
	/**
	 * Lists the sliver's resources at the manager.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class DescribeTask extends AmXmlrpcTask
	{
		public var aggregateSliver:AggregateSliver;
		
		/**
		 * 
		 * @param newSliver Sliver for which to list resources allocated to the sliver's slice
		 * 
		 */
		public function DescribeTask(newSliver:AggregateSliver)
		{
			super(
				newSliver.manager.api.url,
				newSliver.manager.api.version < 3
				? AmXmlrpcTask.METHOD_LISTRESOURCES : AmXmlrpcTask.METHOD_DESCRIBE,
				newSliver.manager.api.version,
				"Describe @ " + newSliver.manager.hrn,
				"Describing resources for aggregate manager " + newSliver.manager.hrn,
				"Describe"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			aggregateSliver = newSliver;
		}
		
		override protected function createFields():void
		{
			if(apiVersion >= 3)
				addOrderedField([aggregateSliver.slice.id.full]);
			addOrderedField([AmXmlrpcTask.credentialToObject(aggregateSliver.slice.credential, apiVersion)]);
			
			var options:Object = { geni_compressed: true };
			if(apiVersion < 3)
			{
				options.geni_available = false;
				options.geni_slice_urn = aggregateSliver.slice.id.full;
			}
			
			var manifestRspecVersion:RspecVersion = aggregateSliver.slice.useInputRspecInfo;
			if(aggregateSliver.manager.inputRspecVersions.get(manifestRspecVersion.type, manifestRspecVersion.version) == null)
				manifestRspecVersion = aggregateSliver.manager.inputRspecVersions.UsableRspecVersions.MaxVersion;
			if(manifestRspecVersion == null)
			{
				afterError(
					new TaskError(
						"There doesn't appear to be a usable RSPEC " + aggregateSliver.manager + " supports which is understood.",
						TaskError.CODE_PROBLEM
					)
				);
				return;
			}
			var rspecVersion:Object = 
				{
					type: manifestRspecVersion.type,
					version: manifestRspecVersion.version.toString()
				};
			if(apiVersion < 2)
				options.rspec_version = rspecVersion;
			else
				options.geni_rspec_version = rspecVersion;
			
			addOrderedField(options);
			
			//V4: geni_cancelled
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			// Sanity check for AM API 2+
			if(apiVersion > 1)
			{
				if(genicode == AmXmlrpcTask.GENICODE_SEARCHFAILED || genicode == AmXmlrpcTask.GENICODE_BADARGS)
				{
					addMessage(
						"No sliver",
						"No sliver found here",
						LogMessage.LEVEL_WARNING,
						LogMessage.IMPORTANCE_HIGH
					);
					super.afterComplete(true);
					return;
				}
				else if(genicode != AmXmlrpcTask.GENICODE_SUCCESS)
				{
					faultOnSuccess();
					return;
				}
			}
			
			try
			{
				var uncompressedRspec:String = apiVersion < 3 ? data : data.geni_rspec;
				if(uncompressedRspec.indexOf("<" ) == -1)
				{
					uncompressedRspec = CompressUtil.uncompress(uncompressedRspec);
				}
				
				addMessage(
					"Manifest received",
					uncompressedRspec,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				if(apiVersion >= 3 && data.geni_slivers != null)
				{
					aggregateSliver.idsToSlivers = new Dictionary();
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
						//V4: geni_next_allocation_status
						aggregateSliver.idsToSlivers[sliver.id.full] = sliver;
						
						var component:VirtualComponent = aggregateSliver.Components.getComponentById(sliver.id.full);
						if(component != null)
							component.copyFrom(sliver);
					}
				}
				
				aggregateSliver.manifest = new Rspec(uncompressedRspec,null,null,null, Rspec.TYPE_MANIFEST);
				parent.add(new ParseRequestManifestTask(aggregateSliver, aggregateSliver.manifest, false, true));
				
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