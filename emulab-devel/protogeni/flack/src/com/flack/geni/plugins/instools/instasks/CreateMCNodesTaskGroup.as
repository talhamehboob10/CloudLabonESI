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
	import com.flack.geni.GeniMain;
	import com.flack.geni.plugins.instools.Instools;
	import com.flack.geni.plugins.instools.SliceInstoolsDetails;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.tasks.groups.slice.SubmitSliceTaskGroup;
	import com.flack.geni.tasks.xmlrpc.am.CreateSliverTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.CreateSliverCmTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.RedeemTicketCmTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.UpdateSliverCmTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.ParallelTaskGroup;
	import com.flack.shared.tasks.Task;
	
	import mx.controls.Alert;
	
	/**
	 * Takes all the information from the added MC Nodes and actually updates the slivers
	 * 
	 * @author mstrum
	 * 
	 */
	public final class CreateMCNodesTaskGroup extends ParallelTaskGroup
	{
		public var details:SliceInstoolsDetails;
		private var prompting:Boolean = false;
		private var deletingAfterProblem:Boolean = false;
		public function CreateMCNodesTaskGroup(newDetails:SliceInstoolsDetails)
		{
			super(
				"Allocate MC Nodes",
				"Allocates all of the MC Nodes which were added"
			);
			relatedTo.push(newDetails.slice);
			details = newDetails;
			
			if(details.creating)
			{
				if(details.slice.UnsubmittedChanges)
					add(new SubmitSliceTaskGroup(newDetails.slice, false));
				else
				{
					// XXX no changes?
				}
			}
		}
		
		override public function completedTask(task:Task):void
		{
			for each(var sliver:AggregateSliver in details.slice.aggregateSlivers.collection)
			{
				if(details.cmurn_to_contact[sliver.manager.id.full] == null || details.cmurn_to_contact[sliver.manager.id.full] == sliver.manager.id.full)
					details.MC_present[sliver.manager.id.full] = Instools.doesSliverHaveMc(sliver);
				else
				{
					var otherSliver:AggregateSliver = details.slice.aggregateSlivers.getByManager(GeniMain.geniUniverse.managers.getById(details.cmurn_to_contact[sliver.manager.id.full]));
					details.MC_present[sliver.manager.id.full] = Instools.doesSliverHaveJuniperMc(otherSliver);
					/*
					for (var key:String in Instools.mcLocation)
					{
					if (Instools.mcLocation[key] == otherSliver.manager.id.full)
					{
					details.MC_present[key] = otherSliver.sliver.Created;
					}
					}*/
					if (Instools.devel_version[otherSliver.manager.id.full] == null)
						add(new InstoolsVersionTask(otherSliver, details));
				}
			}
			super.completedTask(task);
		}
		
		override public function erroredTask(task:Task):void
		{
			Alert.show("Problem!");
			super.erroredTask(task);
		}
		
		override public function canceledTask(task:Task):void
		{
			Alert.show("Problem!");
			super.erroredTask(task);
		}
	}
}
//