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

package com.flack.emulab.tasks.groups
{
	import com.flack.emulab.resources.virtual.Experiment;
	import com.flack.emulab.tasks.xmlrpc.experiment.EmulabExperimentGetVizTask;
	import com.flack.emulab.tasks.xmlrpc.experiment.EmulabExperimentMetadataTask;
	import com.flack.emulab.tasks.xmlrpc.experiment.EmulabExperimentNsFileTask;
	import com.flack.emulab.tasks.xmlrpc.experiment.EmulabExperimentStateTask;
	import com.flack.emulab.tasks.xmlrpc.experiment.EmulabExperimentVirtualTopologyTask;
	import com.flack.shared.tasks.SerialTaskGroup;
	
	/**
	 * Gets all information about an existing slice
	 * 
	 * 1. If resolveSlice and user has authority...
	 *  1a. ResolveSliceSaTask
	 *  1b. GetSliceCredentialSaTask
	 * 2. For each manager...
	 *    If queryAllManagers, or in slice.reportedManagers, or non-ProtoGENI, or no slice authority
	 *  2a. ListSliverResourcesTask/GetSliverCmTask
	 *  2b. ParseManifestTask
	 * 
	 * @author mstrum
	 * 
	 */
	public final class GetExperimentTaskGroup extends SerialTaskGroup
	{
		public var experiment:Experiment;
		
		/**
		 * 
		 * @param taskSlice Slice to get everything for
		 * @param shouldResolveSlice Resolve the slice?
		 * @param shouldQueryAllManagers Query all managers? Needed if resources exist at non-ProtoGENI managers.
		 * 
		 */
		public function GetExperimentTaskGroup(taskExperiment:Experiment)
		{
			super(
				"Get " + taskExperiment.name,
				"Gets all infomation about experiment named " + taskExperiment.name
			);
			relatedTo.push(taskExperiment);
			experiment = taskExperiment;
			
			//add(new EmulabExperimentExpInfoTask(experiment));
			//add(new EmulabExperimentInfoTask(experiment));
			add(new EmulabExperimentMetadataTask(experiment));
			
			add(new EmulabExperimentVirtualTopologyTask(experiment));
			add(new EmulabExperimentNsFileTask(experiment));
			add(new EmulabExperimentGetVizTask(experiment));
			add(new EmulabExperimentStateTask(experiment));
		}
	}
}