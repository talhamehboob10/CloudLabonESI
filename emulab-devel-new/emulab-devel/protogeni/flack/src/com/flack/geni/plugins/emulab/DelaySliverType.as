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
	import com.flack.geni.resources.virt.Ip;
	import com.flack.geni.resources.virt.VirtualInterface;
	import com.flack.geni.resources.virt.VirtualInterfaceCollection;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.hurlant.util.der.ByteString;
	
	import flash.utils.ByteArray;
	
	import mx.collections.ArrayCollection;

	public class DelaySliverType implements SliverTypeInterface
	{
		static public const TYPE_DELAY:String = "delay";
		
		public var pipes:PipeCollection = null;
		
		public function DelaySliverType()
		{
		}
		
		public function get Name():String { return TYPE_DELAY; }
		
		public function get namespace():Namespace
		{
			return new Namespace("delay", "http://www.protogeni.net/resources/rspec/ext/delay/1");
		}
		
		public function get schema():String
		{
			return "http://www.protogeni.net/resources/rspec/ext/delay/1 http://www.protogeni.net/resources/rspec/ext/delay/1/request-delay.xsd";
		}
		
		public function get Part():SliverTypePart { return new DelayGrid(); }
		
		public function get Clone():SliverTypeInterface
		{
			var clone:DelaySliverType = new DelaySliverType();
			return clone;
		}
		
		public function get SimpleList():ArrayCollection
		{
			return new ArrayCollection();
		}
		
		public function canAdd(node:VirtualNode):Boolean
		{
			return true;
		}
		
		public function applyToSliverTypeXml(node:VirtualNode, xml:XML):void
		{
			var sliverTypeShapingXml:XML = <sliver_type_shaping />;
			sliverTypeShapingXml.setNamespace(namespace);
			//sliverTypeShapingXml.@xmlns = XmlUtil.delayNamespace.uri;
			if(pipes != null)
			{
				for each(var pipe:Pipe in pipes.collection)
				{
					var pipeXml:XML = <pipe />;
					pipeXml.setNamespace(namespace);
					pipeXml.@source = pipe.src.clientId
					pipeXml.@dest = pipe.dst.clientId;
					if(pipe.capacity)
						pipeXml.@capacity = pipe.capacity;
					else
						pipeXml.@capacity = 0;
					if(pipe.packetLoss)
						pipeXml.@packet_loss = pipe.packetLoss;
					else
						pipeXml.@packet_loss = 0;
					if(pipe.latency)
						pipeXml.@latency = pipe.latency;
					else
						pipeXml.@latency = 0;
					sliverTypeShapingXml.appendChild(pipeXml);
				}
			}
			
			xml.appendChild(sliverTypeShapingXml);
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
					if(sliverTypeChild.localName() == "sliver_type_shaping")
					{
						pipes = new PipeCollection();
						for each(var pipeXml:XML in sliverTypeChild.children())
						{
							pipes.add(
								new Pipe(
									node.interfaces.getByClientId(String(pipeXml.@source)),
									node.interfaces.getByClientId(String(pipeXml.@dest)),
									pipeXml.@capacity.length() == 1 ? Number(pipeXml.@capacity) : NaN,
									pipeXml.@latency.length() == 1 ? Number(pipeXml.@latency) : NaN,
									pipeXml.@packet_loss.length() == 1 ? Number(pipeXml.@packet_loss) : NaN
								)
							);
						}
					}
				}
			}
		}
		
		public function interfaceRemoved(iface:VirtualInterface):void
		{
			cleanupPipes(iface.Owner);
		}
		public function interfaceAdded(iface:VirtualInterface):void
		{
			cleanupPipes(iface.Owner);
		}
		
		/**
		 * Removes pipes not needed or adds missing pipes. Safe for any node type to call.
		 * 
		 */
		public function cleanupPipes(node:VirtualNode):void
		{
			if(pipes == null)
				pipes = new PipeCollection();
			var i:int;
			// Make sure we have pipes for all interfaces
			for(i = 0; i < node.interfaces.length; i++)
			{
				var first:VirtualInterface = node.interfaces.collection[i];
				for(var j:int = i+1; j < node.interfaces.length; j++)
				{
					var second:VirtualInterface = node.interfaces.collection[j];
					
					var firstPipe:Pipe = pipes.getFor(first, second);
					if(firstPipe == null)
					{
						firstPipe = new Pipe(first, second, Math.min(first.capacity, second.capacity));
						pipes.add(firstPipe);
						node.unsubmittedChanges = true;
					}
					
					var secondPipe:Pipe = pipes.getFor(second, first);
					if(secondPipe == null)
					{
						secondPipe = new Pipe(second, first, Math.min(first.capacity, second.capacity));
						pipes.add(secondPipe);
						node.unsubmittedChanges = true;
					}
				}
			}
			
			// Remove pipes for interfaces which don't exist
			for(i = 0; i < pipes.length; i++)
			{
				var pipe:Pipe = pipes.collection[i];
				if(!node.interfaces.contains(pipe.src) || !node.interfaces.contains(pipe.dst))
				{
					pipes.remove(pipe);
					node.unsubmittedChanges = true;
					i--;
				}
			}
			
			// Ensure everything connected is on the same subnet
			node.interfaces.Links.Interfaces.getByHostOtherThan(node).setupIpAddresses(true);
		}
	}
}