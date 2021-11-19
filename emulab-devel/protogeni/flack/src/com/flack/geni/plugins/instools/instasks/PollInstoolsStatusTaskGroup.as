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
	public class PollInstoolsStatusTaskGroup extends ParallelTaskGroup
	{
		public var details:SliceInstoolsDetails;
		public function PollInstoolsStatusTaskGroup(useDetails:SliceInstoolsDetails)
		{
			super(
				"Finalize INSTOOLS",
				"Polls for instools status, instrumentizes slivers needing to be instrumentized, and completes when instrumentation is completed everywhere"
			);
			relatedTo.push(useDetails.slice);
			details = useDetails;
			
			for each(var sliver:AggregateSliver in details.slice.aggregateSlivers.collection)
			{
				if(details.MC_present[sliver.manager.id.full])
					add(new PollInstoolsStatusTask(sliver, details));
				else
				{
					addMessage(
						"Skipping " + sliver.manager.hrn,
						sliver.manager.hrn + " will not be polled because INSTOOLS was not detected there"
					);
				}
			}
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=true):void
		{
			if(details.hasAnyPortal())
			{
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					details.slice,
					FlackEvent.ACTION_STATUS
				);
				if(details.creating)
				{
					Alert.show(
						"Would you like to visit the INSTOOLS portal for slice '"+details.slice.Name+"' in a new window?",
						"Visit INSTOOLS portal?",
						Alert.YES|Alert.NO,
						FlexGlobals.topLevelApplication as Sprite,
						function closeHandler(e:CloseEvent):void
						{
							if(e.detail == Alert.YES)
								details.goToPortal();
						}
					);
				}
			}
			super.afterComplete(addCompletedMessage);
		}
	}
}