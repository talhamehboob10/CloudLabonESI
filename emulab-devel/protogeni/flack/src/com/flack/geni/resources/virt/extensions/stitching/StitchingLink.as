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

package com.flack.geni.resources.virt.extensions.stitching
{
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.shared.resources.IdentifiableObject;
	import com.flack.shared.resources.IdnUrn;
	
	public class StitchingLink extends IdentifiableObject
	{
		public var remoteLinkId:IdnUrn = new IdnUrn();
		public var manager:GeniManager = null;
		public var trafficEngineeringMetric:Number = NaN;
		public var capacity:Number = NaN;
		public var maximumReservableCapacity:Number = NaN;
		public var minimumReservableCapacity:Number = NaN;
		public var granularity:Number = NaN;
		public var unreservedCapacity:Number = NaN;
		public var switchingCapabilityDescriptors:SwitchingCapabilityDescriptorCollection = new SwitchingCapabilityDescriptorCollection();
		
		public function StitchingLink(newId:String="", newManager:GeniManager=null)
		{
			super(newId);
			manager = newManager;
		}
	}
}