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

package com.flack.geni.plugins.emulab
{
	import com.flack.geni.RspecUtil;
	import com.flack.geni.plugins.SliverTypeInterface;
	import com.flack.geni.plugins.SliverTypePart;
	import com.flack.geni.resources.physical.PhysicalNode;
	import com.flack.geni.resources.virt.VirtualInterface;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;

	public class FirewallSliverType implements SliverTypeInterface
	{
		static public const TYPE_FIREWALL:String = "firewall";
		
		public var firewallStyle:String = "open";
		public var firewallType:String = "";
		
		public function FirewallSliverType()
		{
		}
		
		public function get Name():String { return TYPE_FIREWALL; }
		
		public function get namespace():Namespace
		{
			return new Namespace("firewall", "http://www.protogeni.net/resources/rspec/ext/firewall/1");
		}
		
		public function get schema():String
		{
			return "";
		}

		public function get Part():SliverTypePart { return new FirewallVgroup(); }
		
		public function get Clone():SliverTypeInterface
		{
			var clone:FirewallSliverType = new FirewallSliverType();
			clone.firewallStyle = firewallStyle;
			clone.firewallType = firewallType;
			return clone;
		}
		
		public function get SimpleList():ArrayCollection
		{
			return new ArrayCollection();
		}
		
		public function canAdd(node:VirtualNode):Boolean
		{
			// There can only be one firewall per manager
			var existingFirewall:VirtualNodeCollection = node.slice.nodes.getByManager(node.manager).getBySliverType(FirewallSliverType.TYPE_FIREWALL);
			if(existingFirewall.length > 0 && existingFirewall.collection[0] != node)
				return false;
			return true;
		}
		
		public function applyToSliverTypeXml(node:VirtualNode, xml:XML):void
		{
			var firewallConfigXml:XML = <firewall_config />;
			firewallConfigXml.setNamespace(namespace);
			firewallConfigXml.@style = firewallStyle;
			if(firewallType.length > 0)
				firewallConfigXml.@type = firewallType;
			xml.appendChild(firewallConfigXml);
		}
		
		public function applyFromAdvertisedSliverTypeXml(node:PhysicalNode, xml:XML):void
		{
			applyFromSliverTypeXml(null, xml);
		}
		
		public function applyFromSliverTypeXml(node:VirtualNode, xml:XML):void
		{
			for each(var sliverTypeChild:XML in xml.children())
			{
				if(sliverTypeChild.namespace() == namespace)
				{
					if(sliverTypeChild.localName() == "firewall_config")
					{
						firewallStyle = String(sliverTypeChild.@style);
						firewallType = String(sliverTypeChild.@type);
					}
					
				}
			}
		}
		
		public function interfaceRemoved(iface:VirtualInterface):void
		{
		}
		
		public function interfaceAdded(iface:VirtualInterface):void
		{
		}
		
		// only one per manager
	}
}