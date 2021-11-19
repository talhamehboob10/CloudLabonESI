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

package com.flack.geni.display.mapping
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.physical.PhysicalLink;
	import com.flack.geni.resources.physical.PhysicalLinkCollection;
	import com.flack.geni.resources.physical.PhysicalLocation;
	import com.flack.geni.resources.physical.PhysicalLocationCollection;
	import com.flack.geni.resources.physical.PhysicalNode;
	import com.flack.geni.resources.physical.PhysicalNodeCollection;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.VirtualLink;
	import com.flack.geni.resources.virt.VirtualLinkCollection;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.resources.sites.FlackManager;
	
	import flash.events.Event;
	import flash.utils.Dictionary;
	
	import mx.core.FlexGlobals;
	
	/**
	 * Handles everything for drawing GENI resources onto Google Maps
	 * 
	 * @author mstrum
	 * 
	 */
	public final class GeniMapHandler
	{
		public var map:GeniMap;
		
		// Filters
		private var showManagers:Dictionary = new Dictionary();
		private var selectedNodes:PhysicalNodeCollection = null;
		private var userResourcesOnly:Boolean = false;
		private var selectedSlice:Slice = null;
		
		// What do we have and what will we draw?
		private var allLocations:PhysicalLocationCollection = new PhysicalLocationCollection();
		private var selectedLocations:PhysicalLocationCollection = new PhysicalLocationCollection();
		
		private var mappedMarkers:Vector.<GeniMapNodeMarker>;
		private var mappedLinks:Vector.<GeniMapLink>;
		
		private var clusterer:LocationClusterer;
		
		public function GeniMapHandler(newMap:GeniMap)
		{
			map = newMap;
			clearAll();
			clusterer = new LocationClusterer(selectedLocations, 1)
			SharedMain.sharedDispatcher.addEventListener(FlackEvent.CHANGED_MANAGER, managerChanged);
			SharedMain.sharedDispatcher.addEventListener(FlackEvent.CHANGED_SLICE, sliceChanged);
		}
		
		public function destroy():void
		{
			clearAll();
			SharedMain.sharedDispatcher.removeEventListener(FlackEvent.CHANGED_MANAGER, managerChanged);
			SharedMain.sharedDispatcher.removeEventListener(FlackEvent.CHANGED_SLICE, sliceChanged);
		}
		
		public function clearAll():void
		{
			if(map.Ready)
				map.clearAllOverlays();
			
			if(drawing)
			{
				drawing = false;
				FlexGlobals.topLevelApplication.stage.removeEventListener(Event.ENTER_FRAME, drawNext);
			}
			
			allLocations = new PhysicalLocationCollection;
			selectedLocations = new PhysicalLocationCollection;
			
			mappedMarkers = new Vector.<GeniMapNodeMarker>();
			mappedLinks = new Vector.<GeniMapLink>();
		}
		
		public function zoomToAll():void
		{
			var bounds:LatitudeLongitudeBounds = getBounds();
			map.zoomToFit(bounds);
			map.panToPoint(bounds.Center);
		}
		
		// If nothing given, gives bounds for all resources
		public function getBounds(a:Vector.<LatitudeLongitude> = null):LatitudeLongitudeBounds
		{
			var coords:Vector.<LatitudeLongitude>
			if(a == null)
			{
				coords = new Vector.<LatitudeLongitude>();
				for each(var m:PhysicalLocation in selectedLocations.collection)
					coords.push(new LatitudeLongitude(m.latitude, m.longitude));
			}
			else
				coords = a;
			
			if(coords.length == 0)
				return new LatitudeLongitudeBounds();
			
			var s:Number = (coords[0] as LatitudeLongitude).latitude;
			var n:Number = (coords[0] as LatitudeLongitude).latitude;
			var w:Number = (coords[0] as LatitudeLongitude).longitude;
			var e:Number = (coords[0] as LatitudeLongitude).longitude;
			for each(var ll:LatitudeLongitude in coords)
			{
				if(ll.latitude < s)
					s = ll.latitude;
				else if(ll.latitude > n)
					n = ll.latitude;
				
				if(ll.longitude < w)
					w = ll.longitude;
				if(ll.longitude > e)
					e = ll.longitude;
			}
			
			return new LatitudeLongitudeBounds(new LatitudeLongitude(s,w), new LatitudeLongitude(n,e));
		}
		
		public function panToLocations(l:PhysicalLocationCollection, zoom:Boolean = false):void
		{
			var latlngs:Vector.<LatitudeLongitude> = new Vector.<LatitudeLongitude>();
			for each(var location:PhysicalLocation in l.collection)
				latlngs.push(new LatitudeLongitude(location.latitude, location.longitude));
			var bounds:LatitudeLongitudeBounds = getBounds(latlngs);
			if(zoom)
				map.zoomToFit(bounds);
			map.panToPoint(getBounds(latlngs).Center);
		}
		
		public function panToLocation(l:PhysicalLocation):void
		{
			map.panToPoint(new LatitudeLongitude(l.latitude, l.longitude));
		}
		
		// Handle managers as they are populated
		public var changingManagers:Vector.<GeniManager> = new Vector.<GeniManager>();
		public function managerChanged(event:FlackEvent):void
		{
			if(event.action != FlackEvent.ACTION_POPULATED)
				return;
			
			var manager:GeniManager = event.changedObject as GeniManager;
			
			// Make sure old locations don't still exist
			for(var i:int = 0; i < allLocations.length; i++)
			{
				if(allLocations.collection[i].managerId.full == manager.id.full)
				{
					allLocations.collection.splice(i, 1);
					i--;
				}
			}
			
			// Add all of the new locations
			for each(var location:PhysicalLocation in manager.locations.collection)
				allLocations.add(location);
				
			if(showManagers[manager.id.full] == null)
				showManagers[manager.id.full] = true;
			
			drawMap();
		}
		
		public function sliceChanged(event:FlackEvent):void
		{
			if(userResourcesOnly
				&& (selectedSlice == null || selectedSlice == event.changedObject))
			{
				drawMap();
			}
		}
		
		public function changeUserResources(draw:Boolean = true, slice:Slice = null, drawNow:Boolean = true):void
		{
			userResourcesOnly = draw;
			selectedSlice = slice;
			if(drawNow)
				drawMap();
		}
		
		public function changeShowUser(userOnly:Boolean = false, drawNow:Boolean = true):void
		{
			userResourcesOnly = userOnly;
			if(drawNow)
				drawMap();
		}
		
		public function changeSelected(selected:PhysicalNodeCollection = null, drawNow:Boolean = true):void
		{
			selectedNodes = selected;
			if(drawNow)
				drawMap();
		}
		
		public function changeManagers(managers:GeniManagerCollection = null, shouldShow:Boolean = true, drawNow:Boolean = true):void
		{
			var useManagers:GeniManagerCollection = managers ? managers : GeniMain.geniUniverse.managers;
			for each(var manager:GeniManager in useManagers.collection)
				showManagers[manager.id.full] = shouldShow;
			if(drawNow)
				drawMap();
		}
		
		public function changeManager(manager:GeniManager, shouldShow:Boolean, drawNow:Boolean = true):void
		{
			showManagers[manager.id.full] = shouldShow;
			if(drawNow)
				drawMap();
		}
		
		public function redrawFromScratch():void
		{
			clearAll();
			for each(var gm:GeniManager in GeniMain.geniUniverse.managers.collection)
				changingManagers.push(gm);
			drawMapNow();
		}
		
		public function drawMap(junk:* = null):void
		{
			drawMapNow();
		}
		
		private static var PREPARE_LOCATIONS : int = 0;
		private static var CLUSTER : int = 1;
		private static var CLUSTER_ADD : int = 2;
		private static var LINK_ADD : int = 3;
		private static var DONE : int = 4;
		
		private static var MAX_WORK : int = 10;// 15;
		
		public var myIndex:int;
		public var myState:int;
		public var drawing:Boolean = false;
		public var drawAfter:Boolean = false;
		
		// Create cluster nodes and show/hide components
		public function drawMapNow():void
		{
			if(!map.Ready)
				return;
			
			if(drawing) 
			{
				drawAfter = true;
				return;
			}
			
			drawing = true;
			myIndex = 0;
			myState = PREPARE_LOCATIONS;
			
			FlexGlobals.topLevelApplication.stage.addEventListener(Event.ENTER_FRAME, drawNext);
		}
		
		public function drawNext(event:Event):void
		{
			
			// Stop and start over instead of finishing
			if(drawAfter)
			{
				FlexGlobals.topLevelApplication.stage.removeEventListener(Event.ENTER_FRAME, drawNext);
				drawing = false;
				drawAfter = false;
				drawMap();
				return;
			}
			
			var startTime:Date = new Date();
			
			if(myState == PREPARE_LOCATIONS)
			{
				prepareLocations();
			}
			else if(myState == CLUSTER)
			{
				doCluster();
			}
			else if(myState == CLUSTER_ADD)
			{
				doClusterAdd();
			}
			else if(myState == LINK_ADD)
			{
				doLinkAdd();
			}
			else if(myState == DONE)
			{
				FlexGlobals.topLevelApplication.stage.removeEventListener(Event.ENTER_FRAME, drawNext);
				
				drawing = false;
				if(drawAfter)
				{
					drawAfter = false;
					drawMap();
				}
			}
		}
		
		private var preparedPhysicalNodes:PhysicalNodeCollection;
		private var preparedVirtualNodes:VirtualNodeCollection;
		private var preparedPhysicalLinks:PhysicalLinkCollection;
		private var preparedVirtualLinks:VirtualLinkCollection;
		public function prepareLocations():void
		{
			var shownManagers:GeniManagerCollection = new GeniManagerCollection();
			for(var managerId:String in showManagers)
			{
				if(showManagers[managerId])
					shownManagers.add(GeniMain.geniUniverse.managers.getById(managerId));
			}
			
			if(userResourcesOnly)
			{
				preparedPhysicalLinks = null;
				preparedPhysicalNodes = null;
				if(selectedSlice == null)
				{
					preparedVirtualNodes = GeniMain.geniUniverse.user.slices.Nodes.getByManagers(shownManagers).getNodesByAllocated(true);
					preparedVirtualLinks = GeniMain.geniUniverse.user.slices.Links.getConnectedToManagers(shownManagers);
				}
				else
				{
					preparedVirtualNodes = selectedSlice.nodes.getByManagers(shownManagers).getNodesByAllocated(true);
					preparedVirtualLinks = selectedSlice.links.getConnectedToManagers(shownManagers);
				}
				if(selectedNodes != null)
				{
					for (var i:int=0; i < preparedVirtualNodes.length; i++)
					{
						var preparedVirtualNode:VirtualNode = preparedVirtualNodes.collection[i];
						if(preparedVirtualNode.Physical == null || !selectedNodes.contains(preparedVirtualNode.Physical))
						{
							preparedVirtualNodes.remove(preparedVirtualNode);
							i--;
						}
					}
				}
				selectedLocations = preparedVirtualNodes.PhysicalNodes.Locations;
			}
			else
			{
				preparedVirtualLinks = null;
				preparedVirtualNodes = null;
				preparedPhysicalLinks = new PhysicalLinkCollection();
				if(selectedNodes != null)
				{
					preparedPhysicalNodes = selectedNodes.getByManagers(shownManagers);
					selectedLocations = preparedPhysicalNodes.Locations;
				}
				else
				{
					preparedPhysicalNodes = new PhysicalNodeCollection();
					selectedLocations = new PhysicalLocationCollection()
					for each(var manager:GeniManager in GeniMain.geniUniverse.managers.collection)
					{
						if(manager.Status == FlackManager.STATUS_VALID)
						{
							if(showManagers[manager.id.full])
							{
								for each(var location:PhysicalLocation in manager.locations.collection)
									selectedLocations.add(location);
								for each(var node:PhysicalNode in manager.nodes.collection)
									preparedPhysicalNodes.add(node);
								for each(var link:PhysicalLink in manager.links.collection)
								{
									if(!link.SameSite && link.linkTypes.indexOf("ipv4") == -1)
										preparedPhysicalLinks.add(link);
								}
							}
						}
					}
				}
			}
			
			myState = CLUSTER;
			myIndex = 0;
		}
		
		private var clusteredMarkers:Vector.<PhysicalLocationCollection>;
		public function doCluster():void
		{
			clusterer.zoom = map.getZoomLevel();
			clusterer.locations = selectedLocations;
			clusteredMarkers = clusterer.clusters;
			locationToMarker = new Dictionary();
			
			// Hide shown markers which aren't included in the new shown locations
			for each(var existingMarker:GeniMapNodeMarker in mappedMarkers)
			{
				if(existingMarker.Visible)
				{
					var found:Boolean = false;
					for each(var clusterMarker:PhysicalLocationCollection in clusteredMarkers)
					{
						if(existingMarker.sameLocationAs(clusterMarker.collection))
						{
							found = true;
							break;
						}
					}
					if(!found)
						existingMarker.hide();
				}
			}
			
			myState = CLUSTER_ADD;
			myIndex = 0;
		}
		
		private var locationToMarker:Dictionary;
		public function doClusterAdd():void
		{
			var startTime:Date = new Date();
			var idx:int = 0;
			
			while(myIndex < clusteredMarkers.length)
			{
				var clusterMarker:PhysicalLocationCollection = clusteredMarkers[myIndex];
				
				var clusterNodes:*;
				if(preparedPhysicalNodes != null)
				{
					var clusterPhysicalMarkerNodes:PhysicalNodeCollection = new PhysicalNodeCollection();
					for each(var pnode:PhysicalNode in preparedPhysicalNodes.collection)
					{
						if(clusterMarker.contains(pnode.location))
							clusterPhysicalMarkerNodes.add(pnode);
					}
					clusterNodes = clusterPhysicalMarkerNodes;
				}
				else if(preparedVirtualNodes != null)
				{
					var clusterVirtualMarkerNodes:VirtualNodeCollection = new VirtualNodeCollection();
					for each(var vnode:VirtualNode in preparedVirtualNodes.collection)
					{
						if(clusterMarker.contains(vnode.Physical.location))
							clusterVirtualMarkerNodes.add(vnode);
					}
					clusterNodes = clusterVirtualMarkerNodes;
				}
				
				var found:Boolean = false;
				var myMarker:GeniMapNodeMarker;
				for each(var existingMarker:GeniMapNodeMarker in mappedMarkers)
				{
					if(existingMarker.sameLocationAs(clusterMarker.collection))
					{
						found = true;
						myMarker = existingMarker;
						
						existingMarker.setLook(clusterNodes);
						
						if(!existingMarker.Visible)
							existingMarker.show();
						break;
					}
				}
				if(!found)
				{
					var newMarker:GeniMapNodeMarker = map.getNewNodeMarker(clusterMarker, clusterNodes);
					myMarker = newMarker;
					map.addNodeMarker(newMarker);
					mappedMarkers.push(newMarker);
					
				}
				
				for each(var oldLocation:PhysicalLocation in clusterMarker.collection)
					locationToMarker[oldLocation] = myMarker;
				
				idx++
				myIndex++;
				if(((new Date()).time - startTime.time) > 80) {
					return;
				}
			}
			
			myState = LINK_ADD;
		}
		
		public function doLinkAdd():void
		{
			for each(var d:GeniMapLink in mappedLinks)
			{
				map.removeLink(d);
			}
			mappedLinks = new Vector.<GeniMapLink>();
				
			// cluster together
			if(preparedPhysicalLinks != null)
			{
				for each(var plink:PhysicalLink in preparedPhysicalLinks.collection)
				{
					var allPlinkLocations:PhysicalLocationCollection = plink.interfaces.Locations;
					var connectedPlinkMarkers:Vector.<GeniMapNodeMarker> = new Vector.<GeniMapNodeMarker>();
					for each(var plinkLocation:PhysicalLocation in allPlinkLocations.collection)
					{
						if(connectedPlinkMarkers.indexOf(locationToMarker[plinkLocation]) == -1)
							connectedPlinkMarkers.push(locationToMarker[plinkLocation]);
					}
					
					var foundPlink:Boolean = false;
					for each(var createdPlink:GeniMapLink in mappedLinks)
					{
						if(createdPlink.sameMarkersAs(connectedPlinkMarkers))
						{
							foundPlink = true;
							createdPlink.addLink(plink);
							break;
						}
					}
					if(!foundPlink)
					{
						var newPlink:GeniMapLink = map.getNewLink(connectedPlinkMarkers);
						newPlink.addLink(plink);
						mappedLinks.push(newPlink);
					}
				}
			}
			else if(preparedVirtualLinks != null)
			{
				for each(var vlink:VirtualLink in preparedVirtualLinks.collection)
				{
					var allVlinkLocations:PhysicalLocationCollection = vlink.interfaceRefs.Interfaces.Nodes.PhysicalNodes.Locations;
					var connectedVlinkMarkers:Vector.<GeniMapNodeMarker> = new Vector.<GeniMapNodeMarker>();
					for each(var vlinkLocation:PhysicalLocation in allVlinkLocations.collection)
					{
						if(connectedVlinkMarkers.indexOf(locationToMarker[vlinkLocation]) == -1)
							connectedVlinkMarkers.push(locationToMarker[vlinkLocation]);
					}
					
					var foundVlink:Boolean = false;
					for each(var createdVlink:GeniMapLink in mappedLinks)
					{
						if(createdVlink.sameMarkersAs(connectedVlinkMarkers))
						{
							foundVlink = true;
							createdVlink.addLink(vlink);
							break;
						}
					}
					if(!foundVlink)
					{
						var newVlink:GeniMapLink = map.getNewLink(connectedVlinkMarkers);
						newVlink.addLink(vlink);
						mappedLinks.push(newVlink);
					}
				}
			}
			
			// add
			for each(var addNewLink:GeniMapLink in mappedLinks)
			{
				map.addLink(addNewLink);
			}
			
			myState = DONE;
		}
	}
}