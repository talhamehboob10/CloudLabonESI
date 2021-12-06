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
	import com.flack.geni.GeniMain;
	import com.google.maps.controls.ControlBase;
	import com.google.maps.controls.ControlPosition;
	import com.google.maps.interfaces.IMap;
	
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	
	public class GoogleZoomToAllControl extends ControlBase
	{
		public function GoogleZoomToAllControl()
		{
			super(new ControlPosition(ControlPosition.ANCHOR_TOP_RIGHT, 57, 7));
		}
		
		public override function initControlWithMap(map:IMap):void {
			// first call the base class
			super.initControlWithMap(map);
			createButton("Fit all", 0, 0, function(event:Event):void { GeniMain.mapper.zoomToAll()});
		}
		
		private function createButton(text:String,x:Number,y:Number,callback:Function):void {
			var button:Sprite = new Sprite();
			button.x = x;
			button.y = y;
			
			var buttonWidth:Number = 50;
			
			var label:TextField = new TextField();
			label.text = text;
			label.width = buttonWidth;
			label.selectable = false;
			label.autoSize = TextFieldAutoSize.CENTER;
			var format:TextFormat = new TextFormat("Verdana");
			label.setTextFormat(format);
			
			var background:Shape = new Shape();
			background.graphics.beginFill(0xFFFFFF);
			background.graphics.lineStyle(1, 0x000000);
			background.graphics.drawRoundRect(0, 0, buttonWidth, 18, 4);
			background.graphics.endFill();
			
			button.addChild(background);
			button.addChild(label);
			button.addEventListener(MouseEvent.CLICK, callback);
			
			addChild(button);
		}
	}
}