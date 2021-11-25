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
	import com.esri.ags.SpatialReference;
	import com.esri.ags.geometry.Polyline;
	import com.esri.ags.geometry.WebMercatorMapPoint;
	import com.esri.ags.symbols.SimpleLineSymbol;
	import com.flack.geni.display.mapping.GeniMapLink;
	import com.flack.geni.display.mapping.GeniMapNodeMarker;
	import com.flack.geni.resources.physical.PhysicalLinkCollection;
	import com.flack.geni.resources.virt.VirtualLink;
	import com.flack.geni.resources.virt.VirtualLinkCollection;
	import com.flack.shared.utils.NetUtil;
	
	public class EsriMapLink implements GeniMapLink
	{
		public static const LINK_COLOR:uint = 0xFFCFD1;
		public static const LINK_BORDER_COLOR:uint = 0xFF00FF;
		
		public var lineGraphic:Graphic;
		public var labelGraphics:Vector.<EsriMapLinkMarker> = new Vector.<EsriMapLinkMarker>();
		
		public var markers:Vector.<GeniMapNodeMarker>;
		public var connectedPoints:Array;
		
		public var links:*;
		
		public function EsriMapLink(connectedMarkers:Vector.<GeniMapNodeMarker>)
		{
			markers = connectedMarkers;
			
			connectedPoints = [];
			for each(var marker:GeniMapNodeMarker in markers)
				connectedPoints.push(new WebMercatorMapPoint(marker.LatitudeLongitudeLocation.longitude, marker.LatitudeLongitudeLocation.latitude));
			
			var polyline:Polyline = new Polyline([connectedPoints], new SpatialReference(4326));
			lineGraphic = new Graphic(polyline);
			lineGraphic.symbol = new SimpleLineSymbol(SimpleLineSymbol.STYLE_SOLID, 0xFF00FF, 1, 4);
		}
		
		public function addLinks(newLinks:*):void
		{
			if(links == null)
			{
				if(newLinks is VirtualLinkCollection)
					links = new VirtualLinkCollection();
				else
					links = new PhysicalLinkCollection();
			}
			
			for each(var link:* in newLinks.collection)
			{
				if(!links.contains(link))
					links.add(link);
			}
		}
		
		public function addLink(newLink:*):void
		{
			if(links == null)
			{
				if(newLink is VirtualLink)
					links = new VirtualLinkCollection();
				else
					links = new PhysicalLinkCollection();
			}
			
			if(!links.contains(newLink))
				links.add(newLink);
		}
		
		public function sameMarkersAs(testMarkers:Vector.<GeniMapNodeMarker>):Boolean
		{
			if(testMarkers.length != markers.length)
				return false;
			for each(var testMarker:GeniMapNodeMarker in testMarkers)
			{
				if(markers.indexOf(testMarker) == -1)
					return false;
			}
			return true;
		}
		
		public function generateLabels():void
		{
			labelGraphics = new Vector.<EsriMapLinkMarker>();
			var labelName:String = NetUtil.kbsToString(links.MaximumCapacity);
			for(var i:int = 1; i < connectedPoints.length; i++)
			{
				var label:EsriMapLinkMarker = new EsriMapLinkMarker(
					this,
					new WebMercatorMapPoint(
						(connectedPoints[i-1].lon + connectedPoints[i].lon)/2,
						(connectedPoints[i-1].lat + connectedPoints[i].lat)/2),
					labelName,
					LINK_BORDER_COLOR,
					LINK_COLOR);
				labelGraphics.push(label);
			}
		}
	}
}