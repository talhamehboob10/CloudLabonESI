/* Based on code with original license:
 * Licensed under the Apache License, Version 2.0 (the "License"):
 *    http://www.apache.org/licenses/LICENSE-2.0
 * Code provided in the official examples for Google Maps API for Flash.
 */

package com.flack.geni.display.mapping.mapproviders.googlemapsprovider
{
	import com.flack.geni.GeniMain;
	import com.google.maps.LatLng;
	import com.google.maps.MapEvent;
	import com.google.maps.interfaces.IMap;
	import com.google.maps.interfaces.IPane;
	import com.google.maps.overlays.OverlayBase;
	
	import flash.display.Sprite;
	import flash.filters.DropShadowFilter;
	import flash.geom.Point;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;

	/**
	 * Box with text to show as an overlay on Google Maps API for Flash
	 * 
	 */
	public class GoogleTooltipOverlay extends OverlayBase {
		
		private var latLng:LatLng;
		private var label:String;
		private var textField:TextField;
		private var dropShadow:Sprite;
		private var button:Sprite;
		  
		private var borderColor:Object;
		private var backgroundColor:Object;

		public function GoogleTooltipOverlay(newLatLng:LatLng,
									   newLabel:String,
									   edgeColor:Object,
									   backColor:Object)
		{
			super();
			borderColor = edgeColor;
			backgroundColor = backColor;
			latLng = newLatLng;
			label = newLabel;
			
			addEventListener(MapEvent.OVERLAY_ADDED, onOverlayAdded);
			addEventListener(MapEvent.OVERLAY_REMOVED, onOverlayRemoved);
		}
		
		public function destroy():void
		{
			removeEventListener(MapEvent.OVERLAY_ADDED, onOverlayAdded);
			removeEventListener(MapEvent.OVERLAY_REMOVED, onOverlayRemoved);
		}
		
		public override function getDefaultPane(map:IMap):IPane
		{
			return (GeniMain.mapper.map as GoogleMap).linkPane;
		}
		  
		private function onOverlayAdded(event:MapEvent):void
		{
			var textFormat:TextFormat = new TextFormat();
			textFormat.size = 15;
			textField = new TextField();
			textField.defaultTextFormat = textFormat;
			textField.text = this.label;
			textField.selectable = false;
			textField.border = true;
			textField.borderColor = borderColor as uint;
			textField.background = true;
			textField.multiline = false;
			textField.autoSize = TextFieldAutoSize.CENTER;
			textField.backgroundColor = backgroundColor as uint;
			textField.mouseEnabled = false;
			textField.filters = [new DropShadowFilter()];
			
			button = new Sprite();
			button.buttonMode=true;
			button.useHandCursor = true;
			button.addChild(textField);
			 
			addChild(button);
		}
		
		private function onOverlayRemoved(event:MapEvent):void
		{
			removeChild(button);
			textField = null;
		}
		
		public override function positionOverlay(zoomChanged:Boolean):void
		{
			var point:Point = pane.fromLatLngToPaneCoords(latLng);
			textField.x = point.x - textField.width / 2;
			textField.y = point.y - textField.height / 2;
		}
	}
}