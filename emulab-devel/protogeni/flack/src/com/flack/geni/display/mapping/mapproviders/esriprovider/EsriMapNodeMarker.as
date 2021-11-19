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
	import com.esri.ags.geometry.WebMercatorMapPoint;
	import com.flack.geni.display.mapping.GeniMapNodeMarker;
	import com.flack.geni.display.mapping.LatitudeLongitude;
	import com.flack.geni.resources.physical.PhysicalLocation;
	import com.flack.geni.resources.physical.PhysicalLocationCollection;
	import com.flack.geni.resources.physical.PhysicalNodeCollection;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	
	import flash.events.MouseEvent;
	
	import mx.controls.Alert;
	import mx.core.DragSource;
	import mx.events.DragEvent;
	import mx.managers.DragManager;
	
	public class EsriMapNodeMarker extends Graphic implements GeniMapNodeMarker
	{
		public var locations:PhysicalLocationCollection;
		public var location:PhysicalLocation;
		
		private var nodes:*;
		public function get Nodes():*
		{
			return nodes;
		}
		public function set Nodes(value:*):void
		{
			nodes = value;
		}
		
		public var mapPoint:WebMercatorMapPoint;
		
		private var allowDragging:Boolean = false;
		
		public function EsriMapNodeMarker(newLocations:PhysicalLocationCollection,
										  newNodes:*)
		{
			var newLocation:PhysicalLocation;
			if(newLocations.length > 1)
				newLocation = newLocations.Middle;
			else
				newLocation = newLocations.collection[0];
			
			var newMapPoint:WebMercatorMapPoint = new WebMercatorMapPoint(newLocation.longitude, newLocation.latitude);
			
			super(newMapPoint);
			attributes = {marker: this};
			
			mapPoint = newMapPoint;
			Nodes = newNodes;
			location = newLocation;
			locations = newLocations;
			
			symbol = new EsriMapNodeMarkerSymbol(this);
			
			addEventListener(MouseEvent.MOUSE_MOVE, drag);
			addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
			addEventListener(MouseEvent.ROLL_OUT, mouseExit);
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
				if(nodes is PhysicalNodeCollection)
					ds.addData(this, 'physicalMarker');
				else if(nodes is VirtualNodeCollection)
					ds.addData(this, 'virtualMarker');
				DragManager.doDrag(this, ds, e, (symbol as EsriMapNodeMarkerSymbol).getCopy());
			}
		}
		
		public function t(e:MouseEvent):void
		{
			e.stopPropagation();
			Alert.show("test");
		}
		
		public function get Visible():Boolean
		{
			return visible;
		}
		
		public function get LatitudeLongitudeLocation():LatitudeLongitude
		{
			return new LatitudeLongitude(location.latitude, location.longitude);
		}
		
		public function sameLocationAs(testLocations:Vector.<PhysicalLocation>):Boolean
		{
			if(testLocations.length != locations.length)
				return false;
			for each(var testLocation:PhysicalLocation in testLocations)
			{
				if(!locations.contains(testLocation))
					return false;
			}
			return true;
		}
		
		public function setLook(newNodes:*):void
		{
			// Don't redo marker
			if(nodes != null && newNodes.sameAs(nodes))
				return;
			
			nodes = newNodes;
		}
		
		public function hide():void
		{
			visible = false;
		}
		
		public function show():void
		{
			visible = true;
		}
	}
}