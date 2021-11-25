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

package com.flack.geni.plugins.openflow
{
	import com.flack.geni.plugins.RspecProcessInterface;
	import com.flack.geni.resources.SliverType;
	import com.flack.geni.resources.physical.HardwareType;
	import com.flack.geni.resources.physical.PhysicalInterface;
	import com.flack.geni.resources.physical.PhysicalLocation;
	import com.flack.geni.resources.physical.PhysicalNode;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.resources.docs.Rspec;
	
	public class OpenflowRspecProcessor implements RspecProcessInterface
	{
		public function OpenflowRspecProcessor()
		{
		}
		
		public function applyFrom(object:*, xml:XML):void
		{
			var manager:GeniManager = object as GeniManager;
			var nodes:XMLList = xml.*::datapath;
			for each(var nodeXml:XML in nodes)
			{
				var node:PhysicalNode = new PhysicalNode(manager, String(nodeXml.@component_id));
				node.name = String(nodeXml.@dpid);
				
				var datapathSliverType:SliverType = new SliverType("openflow-switch");
				node.sliverTypes.add(datapathSliverType);
				
				node.hardwareTypes.add(new HardwareType("openflow-switch"));
				
				// Get location info
				var lat:Number = PhysicalLocation.defaultLatitude;
				var lng:Number = PhysicalLocation.defaultLongitude;
				var country:String = "Unknown";
				
				// Assign to a group based on location
				var location:PhysicalLocation = manager.locations.getAt(lat,lng);
				if(location == null)
				{
					location = new PhysicalLocation(manager, lat, lng, country);
					manager.locations.add(location);
				}
				node.location = location;
				location.nodes.add(node);
				
				node.exclusive = false;
				
				var portsXml:XMLList = nodeXml.*::port;
				for each(var portXml:XML in portsXml)
				{
					var dpPort:PhysicalInterface = new PhysicalInterface(node);
					dpPort.role = PhysicalInterface.ROLE_PORT;
					dpPort.id = IdnUrn.makeFrom(node.id.authority, "port", String(portXml.@name));
					dpPort.num = Number(portXml.@num);
					node.interfaces.add(dpPort);
				}
				
				node.available = node.interfaces.length > 0;
				
				node.advertisement = nodeXml.toXMLString();
				manager.nodes.add(node);
			}
		}
		
		public function applyTo(sliver:AggregateSliver, xml:XML):void
		{
		}
		
		public function get namespace():Namespace
		{
			return new Namespace("openflow", "http://www.geni.net/resources/rspec/ext/openflow/3");
		}
		
		public function get schema():String
		{
			return "http://www.geni.net/resources/rspec/ext/openflow/3 http://www.geni.net/resources/rspec/ext/openflow/3/of-resv.xsd";
		}
	}
}