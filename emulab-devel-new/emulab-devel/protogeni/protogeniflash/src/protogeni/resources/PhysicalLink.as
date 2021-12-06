/*
 * Copyright (c) 2009 University of Utah and the Flux Group.
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
 
 package protogeni.resources
{
	import mx.collections.ArrayCollection;
	
	// Physical link between nodes
	public class PhysicalLink
	{
		public function PhysicalLink(own:PhysicalLinkGroup)
		{
			owner = own;
		}
		
		public var owner:PhysicalLinkGroup;
		
		[Bindable]
		public var name:String;
		
		[Bindable]
		public var managerString:String;
		
		[Bindable]
		public var manager:ComponentManager;
		
		[Bindable]
		public var urn:String;
		
		[Bindable]
		public var interface1:PhysicalNodeInterface;
		
		[Bindable]
		public var interface2:PhysicalNodeInterface;
		
		[Bindable]
		public var bandwidth:Number;
		
		[Bindable]
		public var latency:Number;
		
		[Bindable]
		public var packetLoss:Number;
		
		[Bindable]
		public var types:ArrayCollection = new ArrayCollection();

		public var rspec:XML;
		
		public function GetNodes():ArrayCollection {
			var ac:ArrayCollection = new ArrayCollection();
			ac.addItem(interface1.owner);
			ac.addItem(interface2.owner);
			return ac;
		}
	}
}