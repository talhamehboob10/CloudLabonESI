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
	import com.flack.geni.resources.Property;
	import com.flack.geni.resources.PropertyCollection;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.shared.resources.physical.PhysicalComponent;

	/**
	 * Link between two resources as described by a manager advertisement
	 * 
	 * @author mstrum
	 * 
	 */
	public class PhysicalLink extends PhysicalComponent
	{
		[Bindable]
		public var linkTypes:Vector.<String> = new Vector.<String>();
		public var interfaces:PhysicalInterfaceCollection = new PhysicalInterfaceCollection();
		public var properties:PropertyCollection = new PropertyCollection();
		
		private var _capacity:Number = NaN;
		/**
		 * 
		 * @param value Capacity for all paths in the link
		 * 
		 */
		public function set Capacity(value:Number):void
		{
			for each(var sourceInterface:PhysicalInterface in interfaces.collection)
			{
				for each(var destInterface:PhysicalInterface in interfaces.collection)
				{
					if(sourceInterface == destInterface)
						continue;
					var property:Property = properties.getFor(sourceInterface, destInterface);
					if(property == null)
					{
						property = new Property(sourceInterface, destInterface);
						properties.add(property);
					}
					property.capacity = value;
				}
			}
			_capacity = value;
		}
		/**
		 * 
		 * @return Max capacity of the link
		 * 
		 */
		public function get Capacity():Number
		{
			var maxCapacity:Number = 0;
			for each(var property:Property in properties.collection)
			{
				if(property.capacity && property.capacity > maxCapacity)
					maxCapacity = property.capacity;
			}
			return maxCapacity;
		}
		
		private var _packetLoss:Number = NaN;
		/**
		 * 
		 * @param value Packet loss for all paths in the link
		 * 
		 */
		public function set PacketLoss(value:Number):void
		{
			for each(var sourceInterface:PhysicalInterface in interfaces.collection)
			{
				for each(var destInterface:PhysicalInterface in interfaces.collection)
				{
					if(sourceInterface == destInterface)
						continue;
					var property:Property = properties.getFor(sourceInterface, destInterface);
					if(property == null)
					{
						property = new Property(sourceInterface, destInterface);
						properties.add(property);
					}
					property.packetLoss = value;
				}
			}
			_packetLoss = value;
		}
		/**
		 * 
		 * @return Maximum packet loss for all paths in the link
		 * 
		 */
		public function get PacketLoss():Number
		{
			var maxPacketLoss:Number = 0;
			for each(var property:Property in properties.collection)
			{
				if(property.capacity && property.packetLoss > maxPacketLoss)
					maxPacketLoss = property.packetLoss;
			}
			return maxPacketLoss;
		}
		
		private var _latency:Number = NaN;
		/**
		 * 
		 * @param value Latency for all paths in the link
		 * 
		 */
		public function set Latency(value:Number):void
		{
			for each(var sourceInterface:PhysicalInterface in interfaces.collection)
			{
				for each(var destInterface:PhysicalInterface in interfaces.collection)
				{
					if(sourceInterface == destInterface)
						continue;
					var property:Property = properties.getFor(sourceInterface, destInterface);
					if(property == null)
					{
						property = new Property(sourceInterface, destInterface);
						properties.add(property);
					}
					property.latency = value;
				}
			}
			_latency = value;
		}
		/**
		 * 
		 * @return Maximum latency of all the paths in the link
		 * 
		 */
		public function get Latency():Number
		{
			var maxLatency:Number = 0;
			for each(var property:Property in properties.collection)
			{
				if(property.capacity && property.latency > maxLatency)
					maxLatency = property.latency;
			}
			return maxLatency;
		}
		
		/**
		 * 
		 * @param newManager Manager
		 * @param newId IDN-URN
		 * @param newName Short name
		 * @param newAdvertisement Advertisement
		 * 
		 */
		public function PhysicalLink(newManager:GeniManager = null,
									 newId:String = "",
									 newName:String = "",
									 newAdvertisement:String = "")
		{
			super(newManager, newId, newName, newAdvertisement);
		}
		
		/**
		 * 
		 * @return TRUE if the link only uses nodes from the same location
		 * 
		 */
		public function get SameSite():Boolean
		{
			return interfaces.Locations.length == 1;
		}
		
		override public function toString():String
		{
			var result:String =
				"\t\t[PhysicalLink\n"
				+"\t\t\tName="+name
				+",\n\t\t\tID="+id.full
				+",\n\t\tManagerID="+manager.id.full
				+",\n\t\t]";
			if(interfaces.length > 0)
			{
				result += "\n\t\t[InterfaceRefs]";
				for each(var iface:PhysicalInterface in interfaces.collection)
					result += "\n\t\t\t"+iface.toString();
				result += "\n\t\t[/InterfaceRefs]";
			}
			if(linkTypes.length > 0)
			{
				result += "\n\t\t\t[LinkTypes]";
				for each(var htype:String in linkTypes)
					result += "\n\t\t\t\t[LinkType Name="+htype+"]";
				result += "\n\t\t\t[/LinkTypes]";
			}
			if(properties.length > 0)
			{
				result += "\n\t\t[Properties]";
				for each(var property:Property in properties.collection)
					result += "\n\t\t\t"+property.toString();
				result += "\n\t\t[/Properties]";
			}
			
			return result + "\n\t\t[/PhysicalLink]\n";
		}
	}
}