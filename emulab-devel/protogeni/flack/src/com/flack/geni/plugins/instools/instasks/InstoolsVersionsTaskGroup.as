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
	import com.flack.geni.plugins.instools.Instools;
	import com.flack.geni.plugins.instools.SliceInstoolsDetails;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.shared.tasks.ParallelTaskGroup;
	
	/**
	 * Gets the INSTOOLS version info for all managers used in the slice
	 * 
	 * @author mstrum
	 * 
	 */
	public final class InstoolsVersionsTaskGroup extends ParallelTaskGroup
	{
		public var details:SliceInstoolsDetails;
		public function InstoolsVersionsTaskGroup(newDetails:SliceInstoolsDetails)
		{
			super(
				"Get INSTOOLS versions",
				"Gets the INSTOOLS versions at all the managers for the slice"
			);
			relatedTo.push(newDetails.slice);
			details = newDetails;
			
			//details.clear();
			
			// Make sure a sliver exists in the slice for any we will be working on...
			for each(var manager:GeniManager in details.slice.nodes.Managers.collection)
			{
				var sliver:AggregateSliver = details.slice.aggregateSlivers.getOrCreateByManager(manager, details.slice);
				// Try to get INSTOOLS version on managers we don't have any data on
				if(Instools.devel_version[sliver.manager.id.full] == null)
					add(new InstoolsVersionTask(sliver, details));
				else
				{
					addMessage(
						"Skipping " + sliver.manager.hrn,
						"Skipping " + sliver.manager.hrn + " which already reported its INSTOOLS version"
					);
				}
			}
		}
	}
}