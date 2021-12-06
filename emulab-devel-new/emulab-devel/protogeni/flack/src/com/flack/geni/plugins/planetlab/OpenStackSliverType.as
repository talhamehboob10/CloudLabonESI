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

package com.flack.geni.plugins.planetlab
{
	import com.flack.geni.RspecUtil;
	import com.flack.geni.plugins.SliverTypeInterface;
	import com.flack.geni.plugins.SliverTypePart;
	import com.flack.geni.resources.physical.PhysicalNode;
	import com.flack.geni.resources.virt.VirtualInterface;
	import com.flack.geni.resources.virt.VirtualNode;
	
	import mx.collections.ArrayCollection;

	// To be subclassed.
	public class OpenStackSliverType implements SliverTypeInterface
	{
		public var fwRules:Vector.<FwRule> = null;
		
		public function OpenStackSliverType()
		{
		}
		
		public function get Name():String { return ""; }
		
		public function get namespace():Namespace
		{
			return new Namespace("plos", "http://www.planet-lab.org/resources/sfa/ext/plos/1");
		}
		
		public function get schema():String
		{
			return "";
		}
		
		public function get Part():SliverTypePart { return new OpenStackVgroup; }
		
		public function get Clone():SliverTypeInterface
		{
			var clone:OpenStackSliverType = new OpenStackSliverType();
			if(fwRules != null)
			{
				clone.fwRules = new Vector.<FwRule>();
				for each(var fwRule:FwRule in fwRules)
					clone.fwRules.push(new FwRule(fwRule.protocol, fwRule.portRange, fwRule.cidrIp));
			}
			return clone;
		}
		
		public function get SimpleList():ArrayCollection
		{
			var list:ArrayCollection = new ArrayCollection();
			if(fwRules != null)
			{
				for each(var fwRule:FwRule in fwRules)
					list.addItem(fwRule.ToString());
			}
			return list;
		}
		
		public function canAdd(node:VirtualNode):Boolean
		{
			return true;
		}
		
		public function applyToSliverTypeXml(node:VirtualNode, xml:XML):void
		{
			if(fwRules != null)
			{
				for each(var fwRule:FwRule in fwRules)
				{
					var fwRuleXml:XML = new XML("<fw_rule />");
					if(fwRule.protocol.length > 0)
						fwRuleXml.@protocol = fwRule.protocol;
					if(fwRule.portRange.length > 0)
						fwRuleXml.@port_range = fwRule.portRange;
					if(fwRule.cidrIp.length > 0)
						fwRuleXml.@cidr_ip = fwRule.cidrIp;
					fwRuleXml.setNamespace(namespace);
					xml.appendChild(fwRuleXml);
				}
			}
		}
		
		public function applyFromAdvertisedSliverTypeXml(node:PhysicalNode, xml:XML):void
		{
		}
		
		public function applyFromSliverTypeXml(node:VirtualNode, xml:XML):void
		{
		}
		
		public function interfaceRemoved(iface:VirtualInterface):void
		{
		}
		
		public function interfaceAdded(iface:VirtualInterface):void
		{
		}
	}
}