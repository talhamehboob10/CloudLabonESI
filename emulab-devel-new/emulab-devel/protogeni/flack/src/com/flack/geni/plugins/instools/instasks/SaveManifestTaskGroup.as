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
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.tasks.process.GenerateRequestManifestTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.tasks.ParallelTaskGroup;
	
	import flash.display.Sprite;
	
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.events.CloseEvent;
	
	/**
	 * Polls all of the slivers for INSTOOLS status and makes sure everyone is instrumentized
	 * 
	 * @author mstrum
	 * 
	 */
	public class SaveManifestTaskGroup extends ParallelTaskGroup
	{
		public var details:SliceInstoolsDetails;
		public function SaveManifestTaskGroup(useDetails:SliceInstoolsDetails)
		{
			super(
				"Saving Manifest",
				"Sends the combined manifest to each CMs."
			);
			relatedTo.push(useDetails.slice);
			details = useDetails;
			
			var generate:GenerateRequestManifestTask = new GenerateRequestManifestTask(details.slice, true, true);
			generate.start();
			
			for each(var sliver:AggregateSliver in details.slice.aggregateSlivers.collection)
			{
				if(details.MC_present[sliver.manager.id.full])
					add(new SaveManifestTask(sliver, details, generate.resultRspec));
				else
				{
					addMessage(
						"Skipping " + sliver.manager.hrn,
						"Did not send manifest to " + sliver.manager.hrn + " because INSTOOLS was not detected there"
					);
				}
			}
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=true):void
		{
			super.afterComplete(addCompletedMessage);
		}
	}
}