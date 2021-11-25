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

package com.flack.emulab.display
{
	import com.flack.emulab.display.areas.EmulabUserArea;
	import com.flack.emulab.display.areas.ExperimentArea;
	import com.flack.emulab.display.areas.ManagerArea;
	import com.flack.emulab.display.areas.VirtualLinkArea;
	import com.flack.emulab.display.areas.VirtualLinkCollectionArea;
	import com.flack.emulab.display.areas.VirtualNodeArea;
	import com.flack.emulab.display.areas.VirtualNodeCollectionArea;
	import com.flack.emulab.resources.sites.EmulabManager;
	import com.flack.emulab.resources.virtual.Experiment;
	import com.flack.emulab.resources.virtual.VirtualLink;
	import com.flack.emulab.resources.virtual.VirtualLinkCollection;
	import com.flack.emulab.resources.virtual.VirtualNode;
	import com.flack.emulab.resources.virtual.VirtualNodeCollection;
	import com.flack.shared.display.areas.Area;
	import com.flack.shared.display.components.DataButton;
	import com.flack.shared.display.windows.DefaultWindow;
	import com.flack.shared.utils.ColorUtil;
	import com.flack.shared.utils.ImageUtil;
	import com.flack.shared.utils.ViewUtil;

	public class DisplayUtil
	{
		public static function getButtonFor(data:*):DataButton
		{
			if(data is EmulabManager)
				return DisplayUtil.getManagerButton(data);
			else if(data is Experiment)
				return DisplayUtil.getExperimentButton(data);
			else if(data is VirtualNode)
				return DisplayUtil.getVirtualNodeButton(data);
			else if(data is VirtualLink)
				return DisplayUtil.getVirtualLinkButton(data);
			return ViewUtil.getButtonFor(data);
		}
		
		public static function getManagerButton(manager:EmulabManager, handleClick:Boolean = true):DataButton
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
		
		public static function getExperimentButton(e:Experiment):DataButton {
			return new DataButton(
				e.name,
				"Description: " +e.description + "\nProject: " + e.pid,
				null,
				e,
				"experiment"
			);
		}
		
		public static function getVirtualNodeButton(n:VirtualNode, handleClick:Boolean = true):DataButton
		{
			var nodeButton:DataButton = new DataButton(
				n.name,
				"",
				null,
				handleClick ? n : null,
				"virtualNode"
			);
			nodeButton.data = n;
			nodeButton.setStyle("chromeColor", ColorUtil.colorsDark[n.experiment.manager.colorIdx]);
			nodeButton.setStyle("color", ColorUtil.colorsLight[n.experiment.manager.colorIdx]);
			return nodeButton;
		}
		
		public static function getVirtualLinkButton(vl:VirtualLink, handleClick:Boolean = true):DataButton
		{
			var linkButton:DataButton = new DataButton(
											vl.name,
											vl.name,
											ImageUtil.linkIcon,
											handleClick ? vl : null,
											"virtualLink"
										);
			linkButton.data = vl;
			return linkButton;
		}
		
		public static function view(data:*):void
		{
			if(data is EmulabManager)
				viewManager(data);
			else if(data is VirtualNode)
				viewVirtualNode(data);
			else if(data is VirtualNodeCollection)
				viewVirtualNodeCollection(data);
			else if(data is VirtualLink)
				viewVirtualLink(data);
			else if(data is VirtualLinkCollection)
				viewVirtualLinkCollection(data);
			else if(data is Experiment)
				viewExperiment(data);
		}
		
		public static function viewUser():void
		{
			ViewUtil.viewContentInWindow(new EmulabUserArea());
		}
		
		public static function viewManager(manager:EmulabManager):void
		{
			var subarea:ManagerArea = new ManagerArea();
			subarea.load(manager);
			ViewUtil.viewContentInWindow(subarea);
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
				window.title = "Virtual Nodes";
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
				window.title = "Virtual Links";
			else
				window.title = title;
			window.showWindow();
			window.addElement(area);
			area.Root = subarea;
		}
		
		public static function viewExperiment(e:Experiment):void
		{
			var content:ExperimentArea = new ExperimentArea();
			content.experiment = e;
			ViewUtil.viewContentInWindow(content);
		}
	}
}