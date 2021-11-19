/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * Copyright (c) 2011-2012 University of Kentucky.
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

package com.flack.geni.plugins.instools.instasks
{
	import com.flack.geni.plugins.instools.SliceInstoolsDetails;
	import com.flack.geni.tasks.groups.slice.RefreshSliceStatusTaskGroup;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	
	/**
	 * 1. InstoolsVersionsTaskGroup
	 * 		- Get the INSTOOLS versions of the managers
	 * 2. AddMCNodesTaskGroup
	 * 		- Get the new RSPECs at all of the managers
	 * 3. CreateMCNodesTaskGroup
	 * 		- Submit the new RSPECs as needed
	 * 4. RefreshSliceStatusTaskGroup
	 * 		- Make sure the slice is ready
	 * 5. PollInstoolsStatusTaskGroup
	 * 		- Instrumentize everything
	 * 
	 * @author mstrum
	 * 
	 */
	public final class InstrumentizeSliceGroupTask extends SerialTaskGroup
	{
		public var details:SliceInstoolsDetails;
		
		public function InstrumentizeSliceGroupTask(newDetails:SliceInstoolsDetails)
		{
			super(
				"Instrumentize",
				"Instrumentizes the slice"
			);
			relatedTo.push(newDetails.slice);
			details = newDetails;
			
			/*
			details.slice.setSliverStatus(Sliver.STATUS_CHANGING);
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLICE,
				details.slice,
				FlackEvent.ACTION_STATUS
			);
			*/
			
			add(new InstoolsVersionsTaskGroup(details));
		}
		
		override public function completedTask(task:Task):void
		{
			// Got the versions, start adding MC Nodes
			if(task is InstoolsVersionsTaskGroup)
			{
				if(details.creating)
					add(new AddMCNodesTaskGroup(details));
				else
					add(new PollInstoolsStatusTaskGroup(details));
			}
				// Added the nodes, go ahead and create
			else if(task is AddMCNodesTaskGroup)
			{
				add(new CreateMCNodesTaskGroup(details));
			}
				// Created the MC Nodes, make sure slice is ready
			else if(task is CreateMCNodesTaskGroup)
			{
				add(new RefreshSliceStatusTaskGroup(details.slice));
			}
				// Send the manifests to the CMs.
			else if(task is RefreshSliceStatusTaskGroup)
			{
				add(new SaveManifestTaskGroup(details));
			}
				// Slice is ready, instrumentize/check for status
			else if(task is SaveManifestTaskGroup)
			{
				add(new PollInstoolsStatusTaskGroup(details));
			}
			super.completedTask(task);
		}
	}
}