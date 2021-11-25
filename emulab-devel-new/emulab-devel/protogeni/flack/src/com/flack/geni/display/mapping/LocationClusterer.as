/**
 * Distance based clustering solution for google maps markers.
 * 
 * <p>Algorithm based on Mika Tuupola's "Introduction to Marker 
 * Clustering With Google Maps" adapted for use in a dynamic
 * flash map.</p>
 * 
 * Original: https://github.com/vitch/GoogleMapsFlashCluster
 * 
 * @author Kelvin Luck
 * @see http://www.appelsiini.net/2008/11/introduction-to-marker-clustering-with-google-maps
 */

package com.flack.geni.display.mapping
{
	import com.flack.geni.resources.physical.PhysicalLocation;
	import com.flack.geni.resources.physical.PhysicalLocationCollection;
	
	import flash.geom.Point;
	import flash.utils.Dictionary;

	public class LocationClusterer 
	{
		public static const DEFAULT_CLUSTER_RADIUS:int = 70;

		private var _clusters:Vector.<PhysicalLocationCollection>;
		public function get clusters():Vector.<PhysicalLocationCollection>
		{
			if (_invalidated) {
				_clusters = calculateClusters();
				_invalidated = false;
			}
			return _clusters;
		}

		private var _locations:PhysicalLocationCollection;
		public function set locations(value:PhysicalLocationCollection):void
		{
			if (value != _locations) {
				_locations = value;
				_positionedLocations = new Vector.<PositionedLocation>();
				for each (var marker:PhysicalLocation in value.collection) {
					_positionedLocations.push(new PositionedLocation(marker));
				}
				_invalidated = true;
			}
		}

		private var _zoom:int;
		public function set zoom(value:int):void
		{
			if (value != _zoom) {
				_zoom = value;
				_invalidated = true;
			}
		}

		private var _clusterRadius:int;
		public function set clusterRadius(value:int):void
		{
			if (value != _clusterRadius) {
				_clusterRadius = value;
				_invalidated = true;
			}
		}

		private var _invalidated:Boolean;
		private var _positionedLocations:Vector.<PositionedLocation>;

		public function LocationClusterer(newLocations:PhysicalLocationCollection, zoom:int, clusterRadius:int = DEFAULT_CLUSTER_RADIUS)
		{
			locations = newLocations;
			_zoom = zoom;
			_clusterRadius = clusterRadius;
			_invalidated = true;
		}

		private function calculateClusters():Vector.<PhysicalLocationCollection>
		{
			var positionedMarkers:Dictionary = new Dictionary();
			var positionedMarker:PositionedLocation;
			for each (positionedMarker in _positionedLocations) {
				positionedMarkers[positionedMarker.id] = positionedMarker;
			}
			
			// Rather than taking a sqaure root and dividing by a power of 2 to calculate every distance we
			// do the calculation once here (backwards).
			var compareDistance:Number = Math.pow(_clusterRadius * Math.pow(2, 21 - _zoom), 2);
			
			var clusters:Vector.<PhysicalLocationCollection> = new Vector.<PhysicalLocationCollection>();
			var cluster:PhysicalLocationCollection;
			var p1:Point;
			var p2:Point;
			var x:int;
			var y:int;
			var compareMarker:PositionedLocation;
			for each (positionedMarker in positionedMarkers) {
				if (positionedMarker == null) {
					continue;
				}
				positionedMarkers[positionedMarker.id] = null;
				cluster = new PhysicalLocationCollection();
				cluster.add(positionedMarker.location);
				for each (compareMarker in positionedMarkers) {
					if (compareMarker == null) {
						continue;
					}
					p1 = positionedMarker.point;
					p2 = compareMarker.point;
					x = p1.x - p2.x;
					y = p1.y - p2.y;
					if (x * x + y * y < compareDistance) {
						cluster.add(compareMarker.location);
						positionedMarkers[compareMarker.id] = null;
					}
				}
				clusters.push(cluster);
			}
			return clusters;
		}
	}
}

import com.flack.geni.display.mapping.LatitudeLongitude;
import com.flack.geni.resources.physical.PhysicalLocation;

import flash.geom.Point;

internal class PositionedLocation
{

	public static const OFFSET:int = 268435456;
	public static const RADIUS:Number = OFFSET / Math.PI;
	
	// public properties are quicker than getters - speed is important here...
	public var position:LatitudeLongitude;
	public var point:Point;

	private var _location:PhysicalLocation;
	public function get location():PhysicalLocation
	{
		return _location;
	}

	private var _id:int;
	public function get id():int
	{
		return _id;
	}

	private static var globalId:int = 0;

	public function PositionedLocation(newLocation:PhysicalLocation)
	{
		_location = newLocation;
		_id = globalId++;
		position = new LatitudeLongitude(newLocation.latitude, newLocation.longitude);
		
		var o:int = OFFSET;
		var r:Number = RADIUS;
		var d:Number = Math.PI / 180;
		var x:int = Math.round(o + r * position.longitude * d);
		var lat:Number = position.latitude;
		var y:int = Math.round(o - r * Math.log((1 + Math.sin(lat * d)) / (1 - Math.sin(lat * d))) / 2);
		point = new Point(x, y);
	}
}
