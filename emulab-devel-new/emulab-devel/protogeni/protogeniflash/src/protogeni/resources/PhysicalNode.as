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
	
	// Physical node
	public class PhysicalNode
	{
		public function PhysicalNode(own:PhysicalNodeGroup)
		{
			owner = own;
		}
		
		public var owner:PhysicalNodeGroup;
		
		[Bindable]
		public var name:String;
		
		[Bindable]
		public var urn:String;
		
		[Bindable]
		public var managerString:String;
		
		[Bindable]
		public var manager:ComponentManager;
		
		[Bindable]
		public var available:Boolean;
		
		[Bindable]
		public var exclusive:Boolean;
		
		[Bindable]
		public var subNodeOf : PhysicalNode = null;
		public var subNodes : ArrayCollection = new ArrayCollection();
		public var virtualNodes : ArrayCollection = new ArrayCollection();
		
		public var diskImages:ArrayCollection = new ArrayCollection();
		
		[Bindable]
		public var types:ArrayCollection = new ArrayCollection();
		
		[Bindable]
		public var interfaces:PhysicalNodeInterfaceCollection = new PhysicalNodeInterfaceCollection();
		
		public var rspec:XML;
		
		public function IsSwitch():Boolean {
			for each(var d:NodeType in types) {
				if(d.name == "switch")
					return true;
			}
			return false;
		}
		
		public function ConnectedSwitches():ArrayCollection {
			var connectedNodes:ArrayCollection = GetNodes();
			var connectedSwitches:ArrayCollection = new ArrayCollection();
			for each(var connectedNode:PhysicalNode in connectedNodes) {
				if(connectedNode.IsSwitch())
					connectedSwitches.addItem(connectedNode);
			}
			return connectedSwitches;
		}

		public function GetLatitude():Number {
			return owner.latitude;
		}

		public function GetLongitude():Number {
			return owner.longitude;
		}
		
		public function GetLinks():ArrayCollection {
			var ac:ArrayCollection = new ArrayCollection();
			for each(var i:PhysicalNodeInterface in interfaces.collection) {
				for each(var l:PhysicalLink in i.links) {
					ac.addItem(l);
				}
			}
			return ac;
		}
		
		public function GetNodes():ArrayCollection {
			var ac:ArrayCollection = new ArrayCollection();
			for each(var i:PhysicalNodeInterface in interfaces.collection) {
				for each(var l:PhysicalLink in i.links) {
					if(l.interface1.owner != this && !ac.contains(l.interface1.owner)) {
						ac.addItem(l.interface1.owner);
					}
					if(l.interface2.owner != this && !ac.contains(l.interface2.owner)) {
						ac.addItem(l.interface2.owner);
					}
				}
			}
			return ac;
		}
		
		public function GetNodeLinks(n:PhysicalNode):ArrayCollection {
			var ac:ArrayCollection = new ArrayCollection();
			for each(var i:PhysicalNodeInterface in interfaces.collection) {
				for each(var l:PhysicalLink in i.links) {
					if(l.interface1.owner == n || l.interface2.owner == n) {
						ac.addItem(l);
					}
				}
			}
			return ac;
		}
	}
}