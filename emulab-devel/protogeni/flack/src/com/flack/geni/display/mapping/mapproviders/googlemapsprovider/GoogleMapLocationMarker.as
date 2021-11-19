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
	import com.flack.geni.display.mapping.GeniMapNodeMarker;
	import com.flack.geni.display.mapping.LatitudeLongitude;
	import com.flack.geni.resources.physical.PhysicalLocation;
	import com.flack.geni.resources.physical.PhysicalLocationCollection;
	import com.google.maps.InfoWindowOptions;
	import com.google.maps.LatLng;
	import com.google.maps.MapMouseEvent;
	import com.google.maps.overlays.Marker;
	import com.google.maps.overlays.MarkerOptions;
	
	import flash.events.Event;
	import flash.geom.Point;
	
	import mx.core.UIComponent;
	
	/**
	 * Marker to be used for GENI resources on Google Maps
	 * 
	 * @author mstrum
	 * 
	 */
	public class GoogleMapLocationMarker extends Marker implements GeniMapNodeMarker
	{
		public var infoWindow:UIComponent;
		public var mapIcon:GoogleMapLocationMarkerIcon;
		
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
		
		public function GoogleMapLocationMarker(newLocations:PhysicalLocationCollection,
												newNodes:*)
		{
			var newLocation:PhysicalLocation;
			if(newLocations.length > 1)
				newLocation = newLocations.Middle;
			else
				newLocation = newLocations.collection[0];
			
			super(new LatLng(newLocation.latitude, newLocation.longitude));
			
			location = newLocation;
			locations = newLocations;
			
			setLook(newNodes);
			
			addEventListener(MapMouseEvent.CLICK, clicked);
		}
		
		public function destroy():void
		{
			removeEventListener(MapMouseEvent.CLICK, clicked);
			if(mapIcon != null)
				mapIcon.destroy();
		}
		
		public function setLook(newNodes:*):void
		{
			// Don't redo marker
			if(nodes != null && newNodes.sameAs(nodes))
				return;
			
			nodes = newNodes;
			
			if(nodes != null)
			{
				if(mapIcon != null)
					mapIcon.destroy();
				mapIcon = new GoogleMapLocationMarkerIcon(this);
				setOptions(
					new MarkerOptions(
						{
							icon:mapIcon,
							//icon:new PhysicalNodeGroupClusterMarker(this.showGroups.GetAll().length.toString(), this, showGroups.GetType()),
							//iconAllignment:MarkerOptions.ALIGN_RIGHT,
							iconOffset:new Point(-20, -20)
						}
					)
				);
			}
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
		
		public function clicked(e:Event):void
		{
			var clusterInfo:GoogleMapLocationMarkerInfo = new GoogleMapLocationMarkerInfo();
			clusterInfo.load(this);
			infoWindow = clusterInfo;
			
			openInfoWindow(
				new InfoWindowOptions(
					{
						customContent:infoWindow,
						customoffset:new Point(0, 10),
						width:infoWindow.width,
						height:infoWindow.height,
						drawDefaultFrame:true
					}
				)
			);
		}
		
		public function get LatitudeLongitudeLocation():LatitudeLongitude
		{
			var ll:LatLng = getLatLng();
			return new LatitudeLongitude(ll.lat(), ll.lng());
		}
	}
}