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
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	
	import protogeni.Util;
	import protogeni.communication.CommunicationUtil;
	
	// Sliver from a slice containing all resources from the CM
	public class Sliver
	{
		public static var STATE_READY : String = "ready";
	    public static var STATE_NOTREADY : String = "notready";
	    public static var STATE_FAILED : String = "failed";
		
		public static var STATUS_CHANGING:String = "changing";
		public static var STATUS_READY:String = "ready";
		public static var STATUS_NOTREADY:String = "notready";
		public static var STATUS_FAILED:String = "changing";
		public static var STATUS_UNKOWN:String = "unknown";
		public static var STATUS_MIXED:String = "mixed";
		
		public var created:Boolean = false;
	    
		public var credential : Object = null;
		public var componentManager : ComponentManager = null;
		public var rspec : XML = null;
		public var urn : String = null;
		
		public var ticket:XML;
		public var manifest:XML;
		
		public var state : String;
		public var status : String;
		
		public var nodes:VirtualNodeCollection = new VirtualNodeCollection();
		public var links:VirtualLinkCollection = new VirtualLinkCollection();
		
		public var slice : Slice;
		
		public var validUntil:Date;
		
		public function Sliver(owner : Slice, manager:ComponentManager = null)
		{
			slice = owner;
			componentManager = manager;
		}
		
		public function reset():void
		{
			nodes = new VirtualNodeCollection();
			links = new VirtualLinkCollection();
			state = "";
			status = "";
		}
		
		public function localNodes():VirtualNodeCollection
		{
			var on:VirtualNodeCollection = new VirtualNodeCollection();
			for each(var vn:VirtualNode in this.nodes)
			{
				if(vn.manager == this.componentManager)
					on.addItem(vn);
			}
			return on;
		}
		
		public function outsideNodes():VirtualNodeCollection
		{
			var on:VirtualNodeCollection = new VirtualNodeCollection();
			for each(var vn:VirtualNode in this.nodes)
			{
				if(vn.manager != this.componentManager)
					on.addItem(vn);
			}
			return on;
		}
		
		public function getVirtualNodeFor(pn:PhysicalNode):VirtualNode
		{
			for each(var vn:VirtualNode in this.nodes)
			{
				if(vn.physicalNode == pn)
					return vn;
			}
			
			return null;
		}
		
		public function getRequestRspec():XML
		{
			var requestRspec:XML = new XML("<?xml version=\"1.0\" encoding=\"UTF-8\"?> "
				+ "<rspec "
				+ "xmlns=\""+CommunicationUtil.rspec2Namespace+"\" "
				+ "type=\"request\" />");
			
			for each(var vn:VirtualNode in nodes)
				requestRspec.appendChild(vn.getXml());
			
			for each(var vl:VirtualLink in links)
				requestRspec.appendChild(vl.getXml());
			
			return requestRspec;
		}
		
		public function parseRspec():void
		{
			this.validUntil = Util.parseProtogeniDate(rspec.@valid_until);
			
			nodes = new VirtualNodeCollection();
			links = new VirtualLinkCollection();
			
			var nodesById:Dictionary = new Dictionary();
			
			var linksXml : ArrayCollection = new ArrayCollection();
			var nodesXml : ArrayCollection = new ArrayCollection();
	        for each(var component:XML in rspec.children())
	        {
	        	if(component.localName() == "link")
	        		linksXml.addItem(component);
	        	else if(component.localName() == "node")
	        		nodesXml.addItem(component);
	        }
      		
      		for each(var nodeXml:XML in nodesXml)
      		{
				var cmNode:PhysicalNode = componentManager.Nodes.GetByUrn(nodeXml.@component_urn);
				if(cmNode != null)
				{
					var virtualNode:VirtualNode = new VirtualNode(this);
					virtualNode.setToPhysicalNode(componentManager.Nodes.GetByUrn(nodeXml.@component_urn));
					virtualNode.id = nodeXml.@virtual_id;
					virtualNode.manager = Main.protogeniHandler.ComponentManagers.getByUrn(nodeXml.@component_manager_urn);
					if(nodeXml.@sliver_urn != null)
						virtualNode.urn = nodeXml.@sliver_urn;
					if(nodeXml.@sliver_uuid != null)
						virtualNode.uuid = nodeXml.@sliver_uuid;
					if(nodeXml.@sshdport != null)
						virtualNode.sshdport = nodeXml.@sshdport;
					if(nodeXml.@hostname != null)
						virtualNode.hostname = nodeXml.@hostname;
					virtualNode.virtualizationType = nodeXml.@virtualization_type;
					if(nodeXml.@virtualization_subtype != null)
						virtualNode.virtualizationSubtype = nodeXml.@virtualization_subtype;
					for each(var ix:XML in nodeXml.children()) {
						if(ix.localName() == "interface") {
							var virtualInterface:VirtualInterface = new VirtualInterface(virtualNode);
							virtualInterface.id = ix.@virtual_id;
							virtualNode.interfaces.Add(virtualInterface);
						} else if(ix.localName() == "disk_image") {
							virtualNode.diskImage = ix.@name;
						}
					}
					
					virtualNode.rspec = nodeXml.copy();
					nodes.addItem(virtualNode);
					nodesById[virtualNode.id] = virtualNode;
					virtualNode.physicalNode.virtualNodes.addItem(virtualNode);
				}
      			// Don't add outside nodes ... do that if found when parsing links ...
      		}
			
			for each(var vn:VirtualNode in nodes)
			{
				if(vn.physicalNode.subNodeOf != null)
				{
					vn.superNode = nodes.getById(vn.physicalNode.subNodeOf.name);
					nodes.getById(vn.physicalNode.subNodeOf.name).subNodes.push(vn);
				}
			}
      		
      		for each(var linkXml:XML in linksXml)
      		{
      			var virtualLink:VirtualLink = new VirtualLink(this);
      			virtualLink.id = linkXml.@virtual_id;
      			//virtualLink.sliverUrn = linkXml.@sliver_urn;
      			virtualLink.type = linkXml.@link_type;
      			
      			for each(var viXml:XML in linkXml.children()) {
      				if(viXml.localName() == "bandwidth")
      					virtualLink.bandwidth = viXml.toString();
	        		if(viXml.localName() == "interface_ref") {
	        			var vid:String = viXml.@virtual_interface_id;
	      				var nid:String = viXml.@virtual_node_id;
	      				var interfacedNode:VirtualNode = nodesById[nid];
						// Deal with outside node
						if(interfacedNode == null)
						{
							// Get outside node, don't add if not parsed in the other cm yet
							interfacedNode = slice.getVirtualNodeWithId(nid);
							if(interfacedNode == null)
							{
								virtualLink = null;
								break;
							}
						}
	      				for each(var vi:VirtualInterface in interfacedNode.interfaces.collection)
	      				{
	      					if(vi.id == vid)
	      					{
	      						virtualLink.interfaces.addItem(vi);
	      						vi.virtualLinks.addItem(virtualLink);
	      						break;
	      					}
	      				}
      				}
	        	}
      			
				if(virtualLink == null)
					continue;
				
      			virtualLink.rspec = linkXml.copy();
				virtualLink.firstNode = (virtualLink.interfaces[0] as VirtualInterface).virtualNode;
				virtualLink.secondNode = (virtualLink.interfaces[1] as VirtualInterface).virtualNode;
				
				// Deal with tunnel
				if(virtualLink.firstNode.slivers[0] != this)
				{
					Util.addIfNonexistingToArrayCollection(virtualLink.firstNode.slivers, this);
					Util.addIfNonexistingToArrayCollection(virtualLink.secondNode.slivers, virtualLink.firstNode.slivers[0]);
					virtualLink.firstNode.slivers[0].links.addItem(virtualLink);
				} else if(virtualLink.secondNode.slivers[0] != this)
				{
					Util.addIfNonexistingToArrayCollection(virtualLink.secondNode.slivers, this);
					Util.addIfNonexistingToArrayCollection(virtualLink.firstNode.slivers, virtualLink.secondNode.slivers[0]);
					virtualLink.secondNode.slivers[0].links.addItem(virtualLink);
				}
				
				links.addItem(virtualLink);
      		}
		}
		
		public function removeOutsideReferences():void
		{
			for each(var node:VirtualNode in this.nodes)
			{
				if(node.physicalNode.virtualNodes.getItemIndex(node) > -1)
					node.physicalNode.virtualNodes.removeItemAt(node.physicalNode.virtualNodes.getItemIndex(node));
			}
		}
	}
}