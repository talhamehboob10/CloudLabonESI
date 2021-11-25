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

package com.flack.geni.display.mapping.mapproviders.esriprovider
{
	import com.esri.ags.Graphic;
	import com.esri.ags.Map;
	import com.esri.ags.geometry.Geometry;
	import com.esri.ags.geometry.MapPoint;
	import com.esri.ags.symbols.MarkerSymbol;
	import com.esri.ags.symbols.Symbol;
	import com.flack.geni.resources.physical.PhysicalNodeCollection;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	import com.flack.shared.utils.ColorUtil;
	
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.filters.DropShadowFilter;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	
	import mx.core.DragSource;
	import mx.core.IUIComponent;
	import mx.core.UIComponent;
	import mx.managers.DragManager;
	
	public class EsriMapLinkMarkerSymbol extends Symbol
	{
		private var marker:EsriMapLinkMarker;
		
		private var label:String;
		
		private var borderColor:Object;
		private var backgroundColor:Object;
		
		public function EsriMapLinkMarkerSymbol(newMarker:EsriMapLinkMarker,
												newLabel:String,
												edgeColor:Object,
												backColor:Object)
		{
			super();
			borderColor = edgeColor;
			backgroundColor = backColor;
			marker = newMarker;
			label = newLabel;
		}
		
		override public function clear(sprite:Sprite):void
		{
			removeAllChildren(sprite);
			sprite.graphics.clear();
			sprite.x = 0;
			sprite.y = 0;
			sprite.filters = [];
			sprite.buttonMode = false;
		}
		
		
		override public function destroy(sprite:Sprite):void
		{
			clear(sprite);
		}
		
		override public function draw(sprite:Sprite,
									  geometry:Geometry,
									  attributes:Object,
									  map:Map):void
		{
			if (geometry is MapPoint)
			{
				var mapPoint:MapPoint = MapPoint(geometry) as MapPoint;
				sprite.x = toScreenX(map, mapPoint.x)-52;
				sprite.y = toScreenY(map, mapPoint.y)-14;
				
				var textFormat:TextFormat = new TextFormat();
				textFormat.size = 15;
				var textField:TextField = new TextField();
				textField.defaultTextFormat = textFormat;
				textField.text = label;
				textField.selectable = false;
				textField.border = true;
				textField.borderColor = borderColor as uint;
				textField.background = true;
				textField.multiline = false;
				textField.autoSize = TextFieldAutoSize.CENTER;
				textField.backgroundColor = backgroundColor as uint;
				textField.mouseEnabled = false;
				textField.filters = [new DropShadowFilter()];
				
				var button:Sprite = new Sprite();
				button.buttonMode=true;
				button.useHandCursor = true;
				button.addChild(textField);
				
				sprite.addChild(button);
				
				sprite.buttonMode = true;
				sprite.useHandCursor = true;
			}
		}
	}
}