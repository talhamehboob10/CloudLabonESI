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

package com.flack.geni.display.mapping.mapproviders.googlemapsprovider
{
	import com.flack.geni.resources.physical.PhysicalNodeCollection;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	import com.flack.shared.utils.ColorUtil;
	
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.filters.DropShadowFilter;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	
	import mx.core.DragSource;
	import mx.core.UIComponent;
	import mx.managers.DragManager;
	
	/**
	 * Visual part of the marker on the map
	 * 
	 * Code taken from the official tutorials for Google Maps API for Flash
	 * 
	 */
	public class GoogleMapLocationMarkerIcon extends UIComponent
	{
		public var marker:GoogleMapLocationMarker;
		public var managers:GeniManagerCollection;
		public var sprite:Sprite;
		
		private var allowDragging:Boolean = false;
		
		public function GoogleMapLocationMarkerIcon(newMarker:GoogleMapLocationMarker)
		{
			marker = newMarker;
			addEventListener(MouseEvent.MOUSE_MOVE, drag);
			addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
			addEventListener(MouseEvent.ROLL_OUT, mouseExit);
			managers = newMarker.nodes.Managers;
			
			sprite = new Sprite();
			var loc:int;
			if(managers.length > 1)
			{
				var numShownManagers:int = Math.min(managers.length, 5);
				loc = 3*(numShownManagers-1);
				for(var i:int = numShownManagers-1; i > -1; i--)
				{
					sprite.graphics.lineStyle(2, ColorUtil.colorsMedium[managers.collection[i].colorIdx], 1);
					sprite.graphics.beginFill(ColorUtil.colorsDark[managers.collection[i].colorIdx], 1);
					sprite.graphics.drawRoundRect(loc, loc, 28, 28, 10, 10);
					loc -= 3;
				}
			}
			else
			{
				if(newMarker.nodes is PhysicalNodeCollection)
					loc = Math.min(3*((newMarker.nodes as PhysicalNodeCollection).Locations.length-1), 6);
				else if(newMarker.nodes is VirtualNodeCollection)
					loc = Math.min(3*((newMarker.nodes as VirtualNodeCollection).PhysicalNodes.Locations.length-1), 6);
				while(loc > -1)
				{
					sprite.graphics.lineStyle(2, ColorUtil.colorsMedium[managers.collection[0].colorIdx], 1);
					sprite.graphics.beginFill(ColorUtil.colorsDark[managers.collection[0].colorIdx], 1);
					sprite.graphics.drawRoundRect(loc, loc, 28, 28, 10, 10);
					loc -= 3;
				}
			}
			
			var labelMc:TextField = new TextField();
			labelMc.textColor = ColorUtil.colorsLight[managers.collection[0].colorIdx];
			labelMc.selectable = false;
			labelMc.border = false;
			labelMc.embedFonts = false;
			labelMc.mouseEnabled = false;
			labelMc.width = 28;
			labelMc.height = 28;
			labelMc.htmlText = "<b>"+newMarker.nodes.length.toString()+"</b>";
			labelMc.autoSize = TextFieldAutoSize.CENTER;
			labelMc.y = 4;
			sprite.addChild(labelMc);
			addChild(sprite);
			
			// Apply the drop shadow filter to the box.
			var shadow:DropShadowFilter = new DropShadowFilter();
			shadow.distance = 5;
			shadow.angle = 25;
			filters = [shadow];
			
			buttonMode=true;
			useHandCursor = true;
		}
		
		public function destroy():void
		{
			removeEventListener(MouseEvent.MOUSE_MOVE, drag);
			removeEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
			removeEventListener(MouseEvent.ROLL_OUT, mouseExit);
		}
		
		private function mouseDown(event:MouseEvent):void
		{
			allowDragging = true;
		}
		
		private function mouseExit(event:MouseEvent):void
		{
			allowDragging = false;
		}
		
		public function drag(e:MouseEvent):void
		{
			if(allowDragging)
			{
				var ds:DragSource = new DragSource();
				if(marker.nodes is PhysicalNodeCollection)
					ds.addData(marker, 'physicalMarker');
				else if(marker.nodes is VirtualNodeCollection)
					ds.addData(marker, 'virtualMarker');
				var d:GoogleMapLocationMarkerIcon = new GoogleMapLocationMarkerIcon(marker);
				DragManager.doDrag(this, ds, e, d);
			}
		}
	}
}
