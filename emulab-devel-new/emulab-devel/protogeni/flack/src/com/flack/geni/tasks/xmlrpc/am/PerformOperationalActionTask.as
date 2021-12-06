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
	import com.flack.shared.utils.DateUtil;
	
	/**
	 * Performs the given action to change the operational states of the slivers.
	 * 
	 * AM v3+
	 * 
	 * @author mstrum
	 * 
	 */
	public final class PerformOperationalActionTask extends AmXmlrpcTask
	{
		public static const ACTION_START:String = "geni_start";
		public static const ACTION_STOP:String = "geni_stop";
		public static const ACTION_RESTART:String = "geni_restart";
		
		public var aggregateSliver:AggregateSliver;
		public var action:String;
		
		/**
		 * 
		 * @param newSliver Sliver for which to list resources allocated to the sliver's slice
		 * 
		 */
		public function PerformOperationalActionTask(newSliver:AggregateSliver, newAction:String)
		{
			super(
				newSliver.manager.api.url,
				AmXmlrpcTask.METHOD_PERFORMOPERATIONALACTION,
				newSliver.manager.api.version,
				"Perform " + newAction + " @ " + newSliver.manager.hrn,
				"Performing " + newAction + " at aggregate manager " + newSliver.manager.hrn,
				"Perform " + newAction
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.slice);
			relatedTo.push(newSliver.manager);
			aggregateSliver = newSliver;
			action = newAction;
		}
		
		override protected function createFields():void
		{
			var sliverUrns:Array = [];
			for(var sliverId:String in aggregateSliver.idsToSlivers)
				sliverUrns.push(sliverId);
			addOrderedField(sliverUrns);
			addOrderedField([AmXmlrpcTask.credentialToObject(aggregateSliver.slice.credential, apiVersion)]);
			addOrderedField(action);
			addOrderedField({});
			//V3: geni_best_effort
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(genicode == AmXmlrpcTask.GENICODE_SUCCESS)
			{
				for each(var geniSliver:Object in data)
				{
					var sliver:Sliver = new Sliver(
						geniSliver.geni_sliver_urn,
						aggregateSliver.slice,
						geniSliver.geni_allocation_status,
						geniSliver.geni_operational_status);
					sliver.expires = DateUtil.parseRFC3339(geniSliver.geni_expires);
					if(geniSliver.geni_error != null)
						sliver.error = geniSliver.geni_error;
					//V3: geni_resource_status
					aggregateSliver.idsToSlivers[sliver.id.full] = sliver;
					
					var component:VirtualComponent = aggregateSliver.Components.getComponentById(sliver.id.full);
					if(component != null)
						component.copyFrom(sliver);
				}
				
				super.afterComplete(addCompletedMessage);
			}
			else
			{
				faultOnSuccess();
			}
		}
	}
}