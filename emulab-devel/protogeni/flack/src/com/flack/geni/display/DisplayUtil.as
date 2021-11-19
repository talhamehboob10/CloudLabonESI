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

package com.flack.geni.display
{
	import com.flack.geni.display.areas.GeniUserArea;
	import com.flack.geni.display.areas.ManagerArea;
	import com.flack.geni.display.areas.PhysicalInterfaceArea;
	import com.flack.geni.display.areas.PhysicalInterfaceCollectionArea;
	import com.flack.geni.display.areas.PhysicalLinkArea;
	import com.flack.geni.display.areas.PhysicalLinkCollectionArea;
	import com.flack.geni.display.areas.PhysicalNodeArea;
	import com.flack.geni.display.areas.PhysicalNodeCollectionArea;
	import com.flack.geni.display.areas.SliceArea;
	import com.flack.geni.display.areas.VirtualLinkArea;
	import com.flack.geni.display.areas.VirtualLinkCollectionArea;
	import com.flack.geni.display.areas.VirtualNodeArea;
	import com.flack.geni.display.areas.VirtualNodeCollectionArea;
	import com.flack.geni.resources.physical.PhysicalInterface;
	import com.flack.geni.resources.physical.PhysicalInterfaceCollection;
	import com.flack.geni.resources.physical.PhysicalLink;
	import com.flack.geni.resources.physical.PhysicalLinkCollection;
	import com.flack.geni.resources.physical.PhysicalNode;
	import com.flack.geni.resources.physical.PhysicalNodeCollection;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.VirtualLink;
	import com.flack.geni.resources.virt.VirtualLinkCollection;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	import com.flack.shared.display.areas.Area;
	import com.flack.shared.display.components.DataButton;
	import com.flack.shared.display.windows.DefaultWindow;
	import com.flack.shared.utils.ColorUtil;
	import com.flack.shared.utils.ImageUtil;
	import com.flack.shared.utils.ViewUtil;
	import com.flack.geni.display.windows.AddAuthorityWindow;

	public class DisplayUtil
	{
		// Get views
		public static function viewAddAuthorityWindow():void
		{
			var wdw:AddAuthorityWindow = new AddAuthorityWindow();
			wdw.showWindow();
		}
		
		public static function getButtonFor(data:*):DataButton
		{
			if(data is GeniManager)
				return DisplayUtil.getGeniManagerButton(data);
			else if(data is PhysicalNode)
				return DisplayUtil.getPhysicalNodeButton(data);
			else if(data is PhysicalNodeCollection)
				return DisplayUtil.getPhysicalNodeCollectionButton(data);
			else if(data is PhysicalInterface)
				return DisplayUtil.getPhysicalInterfaceButton(data);
			else if(data is PhysicalInterfaceCollection)
				return DisplayUtil.getPhysicalInterfaceCollectionButton(data);
			else if(data is PhysicalLink)
				return DisplayUtil.getPhysicalLinkButton(data);
			else if(data is PhysicalLinkCollection)
				return DisplayUtil.getPhysicalLinkCollectionButton(data);
			else if(data is Slice)
				return DisplayUtil.getSliceButton(data);
			else if(data is VirtualNode)
				return DisplayUtil.getVirtualNodeButton(data);
			else if(data is VirtualLink)
				return DisplayUtil.getVirtualLinkButton(data);
			return ViewUtil.getButtonFor(data);
		}
		
		public static function getGeniManagerButton(manager:GeniManager, handleClick:Boolean = true):DataButton
		{
			var cmButton:DataButton = new DataButton(
				manager.hrn,
				"@ " + manager.url,
				null,
				handleClick ? manager : null,
				"manager"
			);
			cmButton.data = manager;
			cmButton.setStyle("chromeColor", ColorUtil.colorsDark[manager.colorIdx]);
			cmButton.setStyle("color", ColorUtil.colorsLight[manager.colorIdx]);
			return cmButton;
		}
		
		public static function getPhysicalNodeButton(n:PhysicalNode, handleClick:Boolean = true):DataButton
		{
			var nodeButton:DataButton = new DataButton(
				n.name,
				"@" + n.manager.hrn,
				ViewUtil.assignIcon(n.available),
				handleClick ? n : null,
				"physicalNode"
			);
			nodeButton.data = n;
			nodeButton.setStyle("chromeColor", ColorUtil.colorsDark[n.manager.colorIdx]);
			nodeButton.setStyle("color", ColorUtil.colorsLight[n.manager.colorIdx]);
			return nodeButton;
		}
		
		public static function getPhysicalNodeCollectionButton(ng:PhysicalNodeCollection, handleClick:Boolean = true):DataButton
		{
			var nodeButton:DataButton = new DataButton(
				ng.length + " Node" + (ng.length == 1 ? "" : "s"),//newLabel,
				ng.length + " node(s) at " + ng.Managers.length + " manager(s)",
				null,
				handleClick ? ng : null,
				"physicalNodeCollection"
			);
			nodeButton.data = ng;
			nodeButton.enabled = ng.length > 0;
			var managers:GeniManagerCollection = ng.Managers;
			if(managers.length == 1)
			{
				nodeButton.setStyle("chromeColor", ColorUtil.colorsDark[managers.collection[0].colorIdx]);
				nodeButton.setStyle("color", ColorUtil.colorsLight[managers.collection[0].colorIdx]);
			}
			return nodeButton;
		}
		
		public static function getPhysicalInterfaceButton(iface:PhysicalInterface, handleClick:Boolean = true):DataButton
		{
			var ifaceButton:DataButton = new DataButton(
				iface.id.name,
				iface.id.full,
				null,
				handleClick ? iface : null,
				"physicalInterface"
			);
			ifaceButton.data = iface;
			ifaceButton.setStyle("chromeColor", ColorUtil.colorsDark[iface.owner.manager.colorIdx]);
			ifaceButton.setStyle("color", ColorUtil.colorsLight[iface.owner.manager.colorIdx]);
			return ifaceButton;
		}
		
		public static function getPhysicalInterfaceCollectionButton(ifaces:PhysicalInterfaceCollection, handleClick:Boolean = true):DataButton
		{
			var ifaceButton:DataButton = new DataButton(
				ifaces.length + " Interface" + (ifaces.length == 1 ? "" : "s"),//newLabel,
				ifaces.length + " interface(s)",
				null,
				handleClick ? ifaces : null,
				"physicalInterfaceCollection"
			);
			ifaceButton.data = ifaces;
			var managers:GeniManagerCollection = ifaces.Nodes.Managers;
			if(managers.length == 1)
			{
				ifaceButton.setStyle("chromeColor", ColorUtil.colorsDark[managers.collection[0].colorIdx]);
				ifaceButton.setStyle("color", ColorUtil.colorsLight[managers.collection[0].colorIdx]);
			}
			ifaceButton.enabled = ifaces.length > 0;
			return ifaceButton;
		}
		
		public static function getPhysicalLinkButton(link:PhysicalLink, handleClick:Boolean = true):DataButton
		{
			var linkButton:DataButton = new DataButton(
				link.name,
				link.id.full,
				null,
				handleClick ? link : null,
				"physicalLink"
			);
			linkButton.data = link;
			linkButton.setStyle("chromeColor", ColorUtil.colorsDark[link.manager.colorIdx]);
			linkButton.setStyle("color", ColorUtil.colorsLight[link.manager.colorIdx]);
			return linkButton;
		}
		
		public static function getPhysicalLinkCollectionButton(links:PhysicalLinkCollection, handleClick:Boolean = true):DataButton
		{
			var linkButton:DataButton = new DataButton(
				links.length + " Link" + (links.length == 1 ? "" : "s"),
				links.length + " link(s)",
				null,
				handleClick ? links : null,
				"physicalLinkCollection"
			);
			linkButton.data = links;
			if(links.length > 0)
			{
				linkButton.setStyle("chromeColor", ColorUtil.colorsDark[links.collection[0].manager.colorIdx]);
				linkButton.setStyle("color", ColorUtil.colorsLight[links.collection[0].manager.colorIdx]);
			}
			linkButton.enabled = links.length > 0;
			return linkButton;
		}
		
		public static function getSliceButton(s:Slice):DataButton {
			return new DataButton(
				s.id.name,
				s.id.full,
				null,
				s,
				"slice"
			);
		}
		
		public static function getVirtualNodeButton(n:VirtualNode, handleClick:Boolean = true):DataButton
		{
			var nodeButton:DataButton = new DataButton(
				n.clientId,
				"@"+n.manager.hrn,
				null,
				handleClick ? n : null,
				"virtualNode"
			);
			nodeButton.data = n;
			nodeButton.setStyle("chromeColor", ColorUtil.colorsDark[n.manager.colorIdx]);
			nodeButton.setStyle("color", ColorUtil.colorsLight[n.manager.colorIdx]);
			return nodeButton;
		}
		
		public static function getVirtualLinkButton(vl:VirtualLink, handleClick:Boolean = true):DataButton
		{
			var linkButton:DataButton = new DataButton(
											vl.clientId,
											vl.clientId,
											ImageUtil.linkIcon,
											handleClick ? vl : null,
											"virtualLink"
										);
			linkButton.data = vl;
			return linkButton;
		}
		
		public static function view(data:*):void
		{
			if(data is GeniManager)
				viewManager(data);
			else if(data is PhysicalNode)
				viewPhysicalNode(data);
			else if(data is PhysicalNodeCollection)
				viewPhysicalNodeCollection(data);
			else if(data is PhysicalInterface)
				viewPhysicalInterface(data);
			else if(data is PhysicalInterfaceCollection)
				viewPhysicalInterfaceCollection(data);
			else if(data is PhysicalLink)
				viewPhysicalLink(data);
			else if(data is PhysicalLinkCollection)
				viewPhysicalLinkCollection(data);
			else if(data is VirtualNode)
				viewVirtualNode(data);
			else if(data is VirtualNodeCollection)
				viewVirtualNodeCollection(data);
			else if(data is VirtualLink)
				viewVirtualLink(data);
			else if(data is VirtualLinkCollection)
				viewVirtualLinkCollection(data);
			else if(data is Slice)
				viewSlice(data);
		}
		
		public static function viewUser():void
		{
			ViewUtil.viewContentInWindow(new GeniUserArea());
		}
		
		public static function viewManager(manager:GeniManager):void
		{
			var subarea:ManagerArea = new ManagerArea();
			subarea.load(manager);
			ViewUtil.viewContentInWindow(subarea);
		}
		
		public static function viewPhysicalNode(node:PhysicalNode):void
		{
			var subarea:PhysicalNodeArea = new PhysicalNodeArea();
			subarea.load(node);
			ViewUtil.viewContentInWindow(subarea);
		}
		
		public static function viewPhysicalNodeCollection(nodeCollection:PhysicalNodeCollection, title:String = ""):void
		{
			if(nodeCollection.length == 1)
			{
				viewPhysicalNode(nodeCollection.collection[0]);
				return;
			}
			
			var area:Area = new Area();
			var subarea:PhysicalNodeCollectionArea = new PhysicalNodeCollectionArea();
			subarea.Nodes = nodeCollection;
			var window:DefaultWindow = new DefaultWindow();
			area.window = window;
			if(title.length == 0)
			{
				if(nodeCollection.Managers.length == 1)
					window.title = nodeCollection.Managers.collection[0].hrn;
				else
					window.title = "Physical Nodes";
			}
			else
				window.title = title;
			window.showWindow();
			window.addElement(area);
			area.Root = subarea;
		}
		
		public static function viewPhysicalInterface(iface:PhysicalInterface):void
		{
			var subarea:PhysicalInterfaceArea = new PhysicalInterfaceArea();
			subarea.load(iface);
			ViewUtil.viewContentInWindow(subarea);
		}
		
		public static function viewPhysicalInterfaceCollection(ifaceCollection:PhysicalInterfaceCollection,
															   title:String = ""):void
		{
			if(ifaceCollection.length == 1)
			{
				viewPhysicalInterface(ifaceCollection.collection[0]);
				return;
			}
			
			var area:Area = new Area();
			var subarea:PhysicalInterfaceCollectionArea = new PhysicalInterfaceCollectionArea();
			subarea.Interfaces = ifaceCollection;
			var window:DefaultWindow = new DefaultWindow();
			area.window = window;
			if(title.length == 0)
			{
				var managers:GeniManagerCollection = ifaceCollection.Nodes.Managers;
				if(managers.length == 1)
					window.title = managers.collection[0].hrn;
				else
					window.title = "Physical Interfaces";
			}
			else
				window.title = title;
			window.showWindow();
			window.addElement(area);
			area.Root = subarea;
		}
		
		public static function viewPhysicalLink(link:PhysicalLink):void
		{
			var subarea:PhysicalLinkArea = new PhysicalLinkArea();
			subarea.load(link);
			ViewUtil.viewContentInWindow(subarea);
		}
		
		public static function viewPhysicalLinkCollection(linkCollection:PhysicalLinkCollection,
														  title:String = ""):void
		{
			if(linkCollection.length == 1)
			{
				viewPhysicalLink(linkCollection.collection[0]);
				return;
			}
			
			var area:Area = new Area();
			var subarea:PhysicalLinkCollectionArea = new PhysicalLinkCollectionArea();
			subarea.Links = linkCollection;
			var window:DefaultWindow = new DefaultWindow();
			area.window = window;
			if(title.length == 0)
			{
				var managers:GeniManagerCollection = linkCollection.Interfaces.Nodes.Managers;
				if(managers.length == 1)
					window.title = managers.collection[0].hrn;
				else
					window.title = "Physical Links";
			}
			else
				window.title = title;
			window.showWindow();
			window.addElement(area);
			area.Root = subarea;
		}
		
		public static function viewVirtualNode(node:VirtualNode):void
		{
			var subarea:VirtualNodeArea = new VirtualNodeArea();
			subarea.load(node);
			ViewUtil.viewContentInWindow(subarea);
		}
		
		public static function viewVirtualNodeCollection(nodeCollection:VirtualNodeCollection,
														 title:String = ""):void
		{
			if(nodeCollection.length == 1)
			{
				viewVirtualNode(nodeCollection.collection[0]);
				return;
			}
			
			var area:Area = new Area();
			var subarea:VirtualNodeCollectionArea = new VirtualNodeCollectionArea();
			subarea.Nodes = nodeCollection;
			var window:DefaultWindow = new DefaultWindow();
			area.window = window;
			if(title.length == 0)
			{
				if(nodeCollection.Managers.length == 1)
					window.title = nodeCollection.Managers.collection[0].hrn;
				else
					window.title = "Virtual Nodes";
			}
			else
				window.title = title;
			window.showWindow();
			window.addElement(area);
			area.Root = subarea;
		}
		
		public static function viewVirtualLink(link:VirtualLink):void
		{
			var subarea:VirtualLinkArea = new VirtualLinkArea();
			subarea.load(link);
			ViewUtil.viewContentInWindow(subarea);
		}
		
		public static function viewVirtualLinkCollection(linkCollection:VirtualLinkCollection,
														 title:String = ""):void
		{
			if(linkCollection.length == 1)
			{
				viewVirtualLink(linkCollection.collection[0]);
				return;
			}
			
			var area:Area = new Area();
			var subarea:VirtualLinkCollectionArea = new VirtualLinkCollectionArea();
			subarea.Links = linkCollection;
			var window:DefaultWindow = new DefaultWindow();
			area.window = window;
			if(title.length == 0)
			{
				var managers:GeniManagerCollection = linkCollection.Interfaces.Nodes.Managers;
				if(managers.length == 1)
					window.title = managers.collection[0].hrn;
				else
					window.title = "Virtual Links";
			}
			else
				window.title = title;
			window.showWindow();
			window.addElement(area);
			area.Root = subarea;
		}
		
		public static function viewSlice(slice:Slice):void
		{
			var content:SliceArea = new SliceArea();
			content.slice = slice;
			ViewUtil.viewContentInWindow(content);
		}
	}
}