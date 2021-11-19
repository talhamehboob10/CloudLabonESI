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

package com.flack.emulab.resources.virtual
{
	import com.flack.emulab.resources.NamedObject;
	import com.flack.shared.utils.StringUtil;
	
	public class VirtualLink extends NamedObject
	{
		static public const QUEUEING_DROPTAIL:String = "DropTail";
		static public const QUEUEING_GRED:String = "GRED";
		static public const QUEUEING_RED:String = "RED";
		
		static public const TRACING_HEADER:String = "header";
		static public const TRACING_MONITOR:String = "monitor";
		static public const TRACING_PACKET:String = "packet";
		
		static public const WIRELESSPROTOCOL_80211A:String = "80211a";
		static public const WIRELESSPROTOCOL_80211B:String = "80211b";
		static public const WIRELESSPROTOCOL_80211G:String = "80211g";
		static public const WIRELESSPROTOCOL_FLEX900:String = "flex900";
		
		static public const TYPE_LINK:int = 0;
		static public const TYPE_LAN:int = 1;
		
		public var experiment:Experiment;
		public var x:Number = NaN;
		public var y:Number = NaN;
		
		public var type:int;
		
		public var interfaces:VirtualInterfaceCollection = new VirtualInterfaceCollection();
		
		// LINK ONLY
		public var queueing:String = "";
		
		public var netmask:String = "";
		
		// LAN ONLY?
		// XXX traffic flow
		
		// LAN ONLY
		public var wirelessProtocol:String = "";
		public var wirelessAccessPoint:VirtualNode;
		public var wirelessSettings:Vector.<NameValuePair> = null;
		
		// Tracing
		public var tracing:String = "";
		public var tracingFilter:String = "";
		public var tracingLength:Number = NaN;
		
		// other
		public var endNodeShaping:Boolean = false;
		public var noShaping:Boolean = false;
		public var multiplexed:Boolean = false;
		
		public var unsubmittedChanges:Boolean = true;
		
		/**
		 * Capacity (kbs)
		 */
		private var _capacity:Number = NaN;
		/**
		 * 
		 * @param value Capacity (kbs)
		 * 
		 */
		public function set Capacity(value:Number):void
		{
			// set all
			_capacity = value;
		}
		/**
		 * 
		 * @return Capacity (kbs)
		 * 
		 */
		public function get Capacity():Number
		{
			var maxCapacity:Number = 0;
			//
			return maxCapacity;
		}
		
		/**
		 * Packet loss (X/1)
		 */
		private var _packetLoss:Number = NaN;
		/**
		 * 
		 * @param value Packet loss (X/1)
		 * 
		 */
		public function set PacketLoss(value:Number):void
		{
			// set all
			_packetLoss = value;
		}
		/**
		 * 
		 * @return Packet loss (X/1)
		 * 
		 */
		public function get PacketLoss():Number
		{
			var maxPacketLoss:Number = 0;
			//
			return maxPacketLoss;
		}
		
		/**
		 * Latency (ms)
		 */
		private var _latency:Number = NaN;
		/**
		 * 
		 * @param value Latency (ms)
		 * 
		 */
		public function set Latency(value:Number):void
		{
			// set all
			_latency = value;
		}
		/**
		 * 
		 * @return Latency (ms)
		 * 
		 */
		public function get Latency():Number
		{
			var maxLatency:Number = 0;
			//
			return maxLatency;
		}
		
		public function VirtualLink(newExperiment:Experiment, newName:String="")
		{
			super(newName);
			experiment = newExperiment;
		}
		
		public function canEstablish(nodes:VirtualNodeCollection):Boolean
		{
			// Needs to connect at least two nodes
			if(nodes == null
				|| nodes.length == 0
				|| (type == VirtualLink.TYPE_LINK && nodes.length != 2))
				return false;
			
			return true;
		}
		
		public function establish(nodes:VirtualNodeCollection):Boolean
		{
			// Needs to connect at least two nodes
			if(nodes == null || nodes.collection.length < 2)
				return true;
			
			// Allocate interfaces needed
			interfaces = new VirtualInterfaceCollection();
			for each(var connectedNode:VirtualNode in nodes.collection)
			{
				var newInterface:VirtualInterface = connectedNode.allocateExperimentalInterface();
				interfaces.add(newInterface);
				connectedNode.interfaces.add(newInterface);
				newInterface.link = this;
				connectedNode.unsubmittedChanges = true;
			}
			
			name = experiment.getUniqueId(this, "link");
			
			/*
			setUpProperties();
			if(sameManager && needsCapacity)
				Capacity = 100000;
			*/
			
			unsubmittedChanges = true;
			
			return false;
		}
		
		public function canAddNode(node:VirtualNode):Boolean
		{
			// Must already be established
			if(interfaces.length < 2)
				return false;
			
			return true;
		}
		
		public function addNode(node:VirtualNode):Boolean
		{
			if(type == VirtualLink.TYPE_LINK && interfaces.length > 1)
				return true;
			
			// Allocate interface needed
			var newInterface:VirtualInterface = node.allocateExperimentalInterface();
			if(newInterface == null)
				return true;
			
			interfaces.add(newInterface);
			
			newInterface.node.interfaces.add(newInterface);
			newInterface.link = this;
			
			unsubmittedChanges = true;
			
			return false;
		}
		
		public function removeNode(node:VirtualNode):void
		{
			for(var i:int = 0; i < interfaces.length; i++)
			{
				var vi:VirtualInterface = interfaces.collection[i];
				if(vi.node == node)
				{
					removeInterface(vi);
					i--;
				}
			}
			unsubmittedChanges = true;
		}
		
		public function removeInterface(iface:VirtualInterface):void
		{
			iface.node.interfaces.remove(iface);
			iface.link = null;
			
			interfaces.remove(iface);
			
			unsubmittedChanges = true;
		}
		
		public function removeInterfaces():void
		{
			var interfacesToRemove:VirtualInterfaceCollection = interfaces.Clone;
			for each(var iface:VirtualInterface in interfacesToRemove.collection)
			{
				removeInterface(iface);
			}
		}
		
		public function removeFromSlice():void
		{
			experiment.UnsubmittedChanges = true;
			removeInterfaces();
			experiment.links.remove(this);
		}
		
		public function UnboundCloneFor(newExperiment:Experiment):VirtualLink
		{
			var newClone:VirtualLink = new VirtualLink(newExperiment, "");
			if(newExperiment.isIdUnique(newClone, name))
				newClone.name = name;
			else
				newClone.name = newClone.experiment.getUniqueId(newClone, StringUtil.makeSureEndsWith(name,"-"));
			newClone.endNodeShaping = endNodeShaping;
			newClone.multiplexed = multiplexed;
			newClone.noShaping = noShaping;
			newClone.queueing = queueing;
			newClone.type = type;
			newClone.wirelessProtocol = wirelessProtocol;
			if(wirelessSettings != null)
			{
				newClone.wirelessSettings = new Vector.<NameValuePair>();
				for each(var nv:NameValuePair in wirelessSettings)
					newClone.wirelessSettings.push(new NameValuePair(nv.name, nv.value));
			}
			return newClone;
		}
	}
}