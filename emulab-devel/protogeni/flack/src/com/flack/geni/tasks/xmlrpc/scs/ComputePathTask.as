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

package com.flack.geni.tasks.xmlrpc.scs
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.extensions.stitching.StitchingDependency;
	import com.flack.geni.resources.virt.extensions.stitching.StitchingPath;
	import com.flack.geni.tasks.groups.slice.ImportSliceTaskGroup;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.geni.tasks.xmlrpc.am.AmXmlrpcTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	
	/**
	 * Allocates resources
	 * 
	 * AM v3+
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ComputePathTask extends ScsXmlrpcTask
	{
		public var slice:Slice;
		public var request:Rspec;
		public var serviceRspec:String = "";
		
		/**
		 * 
		 * @param newSliver Sliver to allocate resources in
		 * @param newRspec RSPEC to send
		 * 
		 */
		public function ComputePathTask(newSlice:Slice, newRspec:Rspec = null)
		{
			super(
				"http://oingo.dragon.maxgigapop.net:8081/geni/xmlrpc",
				ScsXmlrpcTask.METHOD_COMPUTEPATH,
				"Compute path",
				"Compute path",
				"Compute path"
			);
			relatedTo.push(newSlice);
			
			slice = newSlice;
			request = newRspec;
			
			addMessage(
				"Waiting to compute path...",
				"A path will be computed",
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
		}

		override protected function createFields():void
		{
			addNamedField("slice_urn", slice.id.full);
			addNamedField("request_rspec", request.document);
			addNamedField("request_options", {});
			//geni_hold_path
			//geni_start_time
			//geni_end_time
			//geni_routing_profile
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(genicode == AmXmlrpcTask.GENICODE_SUCCESS)
			{
				serviceRspec = data.service_rspec;
				
				addMessage(
					"Service Rspec received",
					serviceRspec,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				// First, make sure we get the stitching info out.
				var importRspec:ImportSliceTaskGroup = new ImportSliceTaskGroup(
					slice,
					serviceRspec,
					null,
					true
				);
				importRspec.start();
				
				// Next, get the workflow.
				for(var linkName:String in data.workflow_data)
				{
					var linkObj:Object = data.workflow_data[linkName];
					var linkDependencies:Array = linkObj.dependencies;
					var path:StitchingPath = slice.stitching.paths.getByVirtualLinkClientId(linkName);
					for each(var dependencyObj:Object in linkDependencies)
					{
						slice.stitching.dependencies.add(parseDependency(path, dependencyObj));
					}
				}
				
				super.afterComplete(addCompletedMessage);
			}
			else if(genicode == AmXmlrpcTask.GENICODE_BADARGS)
			{
				// Nothing to do?
				faultOnSuccess();
			}
			else
			{
				faultOnSuccess();
			}
		}
		
		public function parseDependency(path:StitchingPath, dependencyObj:Object):StitchingDependency
		{
			var dependency:StitchingDependency = new StitchingDependency();
			dependency.hop = path.hops.getByLinkId(dependencyObj.hop_urn);
			dependency.importVlans = dependencyObj.import_vlans;
			dependency.aggregate = GeniMain.geniUniverse.managers.getById(dependencyObj.aggregate_urn);
			if(dependencyObj.dependencies != null)
			{
				for each(var nextDependencyObj:Object in dependencyObj.dependencies)
				{
					dependency.dependencies.add(parseDependency(path, nextDependencyObj));
				}
			}
			return dependency;
		}
	}
}