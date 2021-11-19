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

package com.flack.geni.display.mapping.mapproviders.mapquestprovider
{
	import com.flack.geni.display.mapping.GeniMapNodeMarker;
	import com.flack.geni.display.mapping.LatitudeLongitude;
	import com.flack.geni.resources.physical.PhysicalLocation;
	import com.flack.geni.resources.physical.PhysicalLocationCollection;
	import com.mapquest.LatLng;
	import com.mapquest.tilemap.pois.Poi;
	
	import flash.events.Event;
	
	public class MapquestMapNodeMarker extends Poi implements GeniMapNodeMarker
	{
		//public var markerIcon:MapquestMapLocationMarkerIcon;
		
		[Bindable]
		public var name:String = "";
		
		public var locations:PhysicalLocationCollection;
		public var location:PhysicalLocation;
		
		public var nodes:*;
		public function get Nodes():*
		{
			return nodes;
		}
		public function set Nodes(value:*):void
		{
			nodes = value;
		}
		
		public function get Visible():Boolean
		{
			return visible;
		}
		
		public function MapquestMapNodeMarker(newLocations:PhysicalLocationCollection,
											  newNodes:*)
		{
			var newLocation:PhysicalLocation;
			if(newLocations.length > 1)
				newLocation = newLocations.Middle;
			else
				newLocation = newLocations.collection[0];
			
			super(new LatLng(newLocation.latitude, newLocation.longitude));
			
			nodes = newNodes;
			location = newLocation;
			locations = newLocations;
		}
		
		public function setLook(newNodes:*):void
		{
			// Don't redo marker
			if(nodes != null && newNodes.sameAs(nodes))
				return;
			
			nodes = newNodes;
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
		
		public function destroy():void
		{
		}
		
		public function clicked(e:Event):void
		{
		}
		
		public function show():void
		{
			super.visible = true;
		}
		
		public function hide():void
		{
			super.visible = false;
		}
		
		public function get LatitudeLongitudeLocation():LatitudeLongitude
		{
			return new LatitudeLongitude(latLng.lat, latLng.lng);
		}
	}
}