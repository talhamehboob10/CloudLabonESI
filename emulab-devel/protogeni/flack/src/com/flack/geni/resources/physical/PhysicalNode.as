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

package com.flack.geni.resources.physical
{
	import com.flack.geni.resources.SliverType;
	import com.flack.geni.resources.SliverTypeCollection;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.shared.resources.physical.PhysicalComponent;

	/**
	 * Resource as described by a manager's advertisement
	 * 
	 * @author mstrum
	 * 
	 */
	public class PhysicalNode extends PhysicalComponent
	{
		public var location:PhysicalLocation;
		
		[Bindable]
		public var exclusive:Boolean;
		[Bindable]
		public var available:Boolean;
		[Bindable]
		public var subNodeOf:PhysicalNode;
		public var subNodes:Vector.<PhysicalNode>;
		[Bindable]
		public var hardwareTypes:HardwareTypeCollection = new HardwareTypeCollection();
		[Bindable]
		public var sliverTypes:SliverTypeCollection = new SliverTypeCollection();
		[Bindable]
		public var interfaces:PhysicalInterfaceCollection = new PhysicalInterfaceCollection();
		
		public var cpuSpeed:int = 0;
		public var ramSize:int = 0;
		
		/**
		 * 
		 * @param newManager Manager where the node is hosted
		 * @param newId IDN-URN id
		 * @param newName Short name for the node
		 * @param newAdvertisement Advertisement
		 * 
		 */
		public function PhysicalNode(newManager:GeniManager = null,
									 newId:String = "",
									 newName:String = "",
									 newAdvertisement:String = "")
		{
			super(newManager,
				newId,
				newName,
				newAdvertisement
			);
		}
		
		/**
		 * 
		 * @return TRUE if the node is a switch
		 * 
		 */
		public function get IsSwitch():Boolean
		{
			return hardwareTypes.getByName("switch") != null;
		}
		
		/**
		 * 
		 * @return All connected links
		 * 
		 */
		public function get Links():PhysicalLinkCollection
		{
			var ac:PhysicalLinkCollection = new PhysicalLinkCollection;
			for each(var i:PhysicalInterface in interfaces.collection)
			{
				for each(var l:PhysicalLink in i.links.collection)
					ac.add(l);
			}
			return ac;
		}
		
		/**
		 * 
		 * @param node Other node
		 * @return Common links between this and the other node
		 * 
		 */
		public function getLinksWith(node:PhysicalNode):PhysicalLinkCollection
		{
			var ac:PhysicalLinkCollection = new PhysicalLinkCollection;
			for each(var i:PhysicalInterface in interfaces.collection)
			{
				for each(var l:PhysicalLink in i.links.collection)
				{
					if(l.interfaces.Nodes.contains(node) && !ac.contains(l))
					{
						ac.add(l);
						break;
					}
				}
			}
			return ac;
		}
		
		/**
		 * 
		 * @return All connected nodes
		 * 
		 */
		public function get ConnectedNodes():PhysicalNodeCollection
		{
			var ac:PhysicalNodeCollection = interfaces.Links.Interfaces.Nodes;
			ac.remove(this);
			return ac;
		}
		
		/**
		 * 
		 * @return All connected switches
		 * 
		 */
		public function get ConnectedSwitches():PhysicalNodeCollection
		{
			var connectedNodes:PhysicalNodeCollection = ConnectedNodes;
			var connectedSwitches:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each(var connectedNode:PhysicalNode in connectedNodes)
			{
				if(connectedNode.IsSwitch)
					connectedSwitches.add(connectedNode);
			}
			return connectedSwitches;
		}
		
		/**
		 * 
		 * @param name Partial name
		 * @param availableOnly Should the node be available?
		 * @param type Hardware type we are looking for
		 * @return TRUE if this node meets the criteria
		 * 
		 */
		public function search(name:String, availableOnly:Boolean, type:String):Boolean
		{
			if(availableOnly && !available)
				return false;
			if(type.length > 0 && hardwareTypes.getByName(type) == null)
				return false;
			if(name.length == 0)
				return true;
			
			for each(var iface:PhysicalInterface in interfaces.collection)
			{
				if(iface.id.full.indexOf(name) != -1)
					return true;
			}
			if(id.full.indexOf(name) != -1)
				return true;
			
			return false;
		}
		
		override public function toString():String
		{
			var result:String = "\t\t[PhysicalNode\n"
				+"\t\t\tName="+name
				+",\n\t\t\tID="+id.full
				+",\n\t\t\tExclusive="+exclusive
				+",\n\t\t\tManagerID="+manager.id.full
				+",\n\t\t]";
			if(interfaces.length > 0)
			{
				result += "\n\t\t\t[Interfaces]";
				for each(var iface:PhysicalInterface in interfaces.collection)
					result += "\n\t\t\t\t"+iface.toString();
				result += "\n\t\t\t[/Interfaces]";
			}
			if(hardwareTypes.length > 0)
			{
				result += "\n\t\t\t[HardwareTypes]";
				for each(var htype:String in hardwareTypes)
					result += "\n\t\t\t\t[HardwareType Name="+htype+"]";
				result += "\n\t\t\t[/HardwareTypes]";
			}
			if(sliverTypes.length > 0)
			{
				result += "\n\t\t\t[SliverTypes]";
				for each(var sliverType:SliverType in sliverTypes.collection)
					result += "\n\t\t\t\t"+sliverType.toString();
				result += "\n\t\t\t[/SliverTypes]";
			}
			return result + "\n\t\t[/PhysicalNode]\n";
		}
	}
}