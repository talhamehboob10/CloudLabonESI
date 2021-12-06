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

package com.flack.geni.display.slicer.graphview
{
	import com.flack.geni.resources.virt.LinkType;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.resources.virt.VirtualComponent;
	import com.flack.geni.resources.virt.VirtualLink;
	import com.flack.shared.utils.ColorUtil;
	
	import flash.display.CapsStyle;
	import flash.display.LineScaleMode;
	import flash.display.Sprite;
	import flash.filters.GlowFilter;
	import flash.geom.Point;
	
	import mx.core.UIComponent;
	
	/**
	 * VirtualLink for use on the slice canvas
	 * 
	 * @author mstrum
	 * 
	 */
	public final class CanvasLink extends UIComponent
	{
		public static const NORMAL_DARK:uint = 0x000000;
		public static const NORMAL_LIGHT:uint = 0xFFFFFF;
		public static const TUNNEL_DARK:uint = 0x00FFFF;
		public static const TUNNEL_LIGHT:uint = 0x000000;
		public static const ION_DARK:uint = 0xCC33CC;
		public static const ION_LIGHT:uint = 0x000000;
		public static const GPENI_DARK:uint = 0x0000FF;
		public static const GPENI_LIGHT:uint = 0x000000;
		
		public static const INVALID_COLOR:uint = 0xFF0000;
		public static const VALID_COLOR:uint = 0x00FF00;
		
		public var labelColor:uint;
		public var labelBackgroundColor:uint;
		public var linkColor:uint;
		
		public var link:VirtualLink;
		public var canvas:SliceCanvas;
		
		private var rawSprite:Sprite;
		
		public var button:CanvasLinkMain;
		public var buttons:Vector.<CanvasLinkBranch>;
		public function getButtonFor(cn:CanvasNode):CanvasLinkBranch
		{
			for each(var bl:CanvasLinkBranch in buttons)
			{
				if(bl.iface.Owner == cn.Node)
					return bl;
			}
			return null;
		}
		
		public function setFilters(newFilters:Array):void
		{
			rawSprite.filters = newFilters;
			button.setFilters(newFilters);
			for each(var bl:CanvasLinkBranch in buttons)
				bl.setFilters(newFilters);
		}
		
		public function CanvasLink(newCanvas:SliceCanvas)
		{
			super();
			canvas = newCanvas;
			
			rawSprite = new Sprite();
			addChild(rawSprite);
			
			labelBackgroundColor = NORMAL_DARK;
			labelColor = NORMAL_LIGHT;
			linkColor = NORMAL_DARK;
			
			button = new CanvasLinkMain();
			buttons = new Vector.<CanvasLinkBranch>();
		}
		
		public function clearStatus():void
		{
			toolTip = "";
			button.labelBackgroundColor = ColorUtil.unknownLight;
			button.labelColor = ColorUtil.unknownDark;
			for each(var d:CanvasLinkBranch in buttons)
				d.color = ColorUtil.unknownLight;
		}
		
		public function establishFromExisting(vl:VirtualLink):void
		{
			removeButtonsFromCanvas();
			buttons = new Vector.<CanvasLinkBranch>();
			link = vl;
			
			button.canvasLink = this;
			if(link.flackInfo.x != -1)
			{
				button.x = link.flackInfo.x;
				button.y = link.flackInfo.y;
			}
			if(canvas.contains(button))
				canvas.setElementIndex(button, 0);
			else
				canvas.addElementAt(button, 0);
			button.validateNow();
			button.Link = link;
			
			if(link.interfaceRefs.length > 2)
			{
				var canvasNodes:CanvasNodeCollection = canvas.allNodes.getForVirtualNodes(link.interfaceRefs.Interfaces.Nodes);
				for each(var node:CanvasNode in canvasNodes.collection)
				{
					var newBranchLabel:CanvasLinkBranch = new CanvasLinkBranch();
					newBranchLabel.canvasLink = this;
					canvas.addElementAt(newBranchLabel, 0);
					newBranchLabel.validateNow();
					newBranchLabel.setTo(link, link.interfaceRefs.Interfaces.getByHost(node.Node));
					
					buttons.push(newBranchLabel);
				}
			}
			
			canvas.validateNow();
			canvas.setElementIndex(this, 0);
			drawEstablished();
		}
		
		private var editable:Boolean = true;
		public function setEditable(isEditable:Boolean):void
		{
			editable = isEditable;
			button.editable = editable;
			for each(var g:CanvasLinkBranch in buttons)
				g.editable = editable;
		}
		
		private function removeButtonsFromCanvas():void
		{
			for each(var g:CanvasLinkBranch in buttons)
			{
				if(canvas.contains(g))
					canvas.removeElement(g);
			}
		}
		
		public function removeFromCanvas():void
		{
			removeButtonsFromCanvas();
			canvas.removeElement(button);
			canvas.removeElement(this);
		}
		
		public function removeBranch(bl:CanvasLinkBranch):void
		{
			link.removeInterface(bl.iface);
			canvas.removeElement(bl);
			buttons.splice(buttons.indexOf(bl), 1);
			drawEstablished();
		}
		
		public function get MiddlePoint():Point
		{
			return button.MiddlePoint;
		}
		
		public function get MiddleX():Number
		{
			return button.MiddleX;
		}
		
		public function get MiddleY():Number
		{
			return button.MiddleY;
		}
		
		public function get ContainerWidth():Number
		{
			return button.ContainerWidth;
		}
		
		public function get ContainerHeight():Number
		{
			return button.ContainerHeight;
		}
		
		public function setLocation(newX:Number = -1, newY:Number = -1):void
		{
			if(newX != 0 && newX != 0 && link.flackInfo.x == -1)
			{
				link.flackInfo.x = newX;
				link.flackInfo.y = newY;
			}
			button.setLocation(newX, newY);
		}
		
		public function drawEstablished():void
		{
			labelColor = NORMAL_LIGHT;
			labelBackgroundColor = NORMAL_DARK;
			switch(link.type.name) {
				case LinkType.GRETUNNEL_V2:
					labelBackgroundColor = TUNNEL_DARK;
					labelColor = TUNNEL_LIGHT;
					break;
				case LinkType.GPENI:
					labelBackgroundColor = GPENI_DARK;
					labelColor = GPENI_LIGHT;
					break;
				case LinkType.ION:
					labelBackgroundColor = ION_DARK;
					labelColor = ION_LIGHT;
					break;
			}
			
			var newLinkColor:uint = labelBackgroundColor;
			if(link != null)
			{
				switch(link.allocationState)
				{
					case Sliver.ALLOCATION_PROVISIONED:
						switch(link.operationalState)
						{
							case Sliver.OPERATIONAL_READY:
								newLinkColor = ColorUtil.validLight;
								break;
							case Sliver.OPERATIONAL_FAILED:
								newLinkColor = ColorUtil.invalidLight;
								toolTip = "Error: " + link.error;
								break;
							case Sliver.OPERATIONAL_STOPPING:
							case Sliver.OPERATIONAL_READY_BUSY:
							case Sliver.OPERATIONAL_CONFIGURING:
								newLinkColor = ColorUtil.changingLight;
								toolTip = "Status is changing...";
								break;
							case Sliver.OPERATIONAL_NOTREADY:
								newLinkColor = ColorUtil.changingLight;
								toolTip = "Link is not ready";
								break;
							default:
								newLinkColor = labelBackgroundColor;
						}
						break;
					case Sliver.ALLOCATION_ALLOCATED:
					case Sliver.ALLOCATION_UPDATING:
						newLinkColor = ColorUtil.changingLight;
						toolTip = "Status is changing...";
						break;
					default:
						newLinkColor = labelBackgroundColor;
				}
			}
			else
				toolTip = "";
			linkColor = newLinkColor;
			
			drawLink();
		}
		
		private function drawLink():void
		{
			rawSprite.graphics.clear();
			rawSprite.graphics.lineStyle(
				2,
				linkColor,
				1.0,
				true,
				LineScaleMode.NORMAL,
				CapsStyle.ROUND
			);
			
			var canvasNodes:CanvasNodeCollection = canvas.allNodes.getForVirtualNodes(link.interfaceRefs.Interfaces.Nodes);
			
			if(link.flackInfo.x != -1)
			{
				button.x = link.flackInfo.x;
				button.y = link.flackInfo.y;
			}
			else
			{
				button.x = canvasNodes.MiddleX-48;
				button.y = canvasNodes.MiddleY-12;
			}
			
			if(canvasNodes.length < 3)
			{
				removeButtonsFromCanvas();
				if(buttons.length > 0)
					buttons = new Vector.<CanvasLinkBranch>();
			}
			
			for each(var cnode:CanvasNode in canvasNodes.collection)
			{
				rawSprite.graphics.moveTo(button.MiddleX, button.MiddleY);
				rawSprite.graphics.lineTo(cnode.MiddleX, cnode.MiddleY);
				
				if(canvasNodes.length > 2)
				{
					var buttonGroup:CanvasLinkBranch = getButtonFor(cnode);
					buttonGroup.setTo(link, link.interfaceRefs.Interfaces.getByHost(cnode.Node));
					buttonGroup.x = (button.MiddleX + cnode.MiddleX)/2 - (buttonGroup.ContainerWidth/2 + 1);
					buttonGroup.y = (button.MiddleY + cnode.MiddleY)/2 - (buttonGroup.ContainerHeight/2);
					buttonGroup.color = labelBackgroundColor;
				}
			}
			
			button.Link = link;
			button.labelBackgroundColor = labelBackgroundColor;
			button.labelColor = labelColor;
		}
	}
}