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
	import com.flack.geni.display.DisplayUtil;
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
	
	public class EsriMapLinkMarker extends Graphic
	{
		public var mapPoint:WebMercatorMapPoint;
		public var link:EsriMapLink;
		
		public function EsriMapLinkMarker(newLink:EsriMapLink,
										  newPoint:WebMercatorMapPoint,
										  newLabel:String,
										  edgeColor:Object,
										  backColor:Object)
		{
			super(newPoint);
			link = newLink;
			mapPoint = newPoint;
			
			symbol = new EsriMapLinkMarkerSymbol(
				this,
				newLabel,
				edgeColor,
				backColor);
			
			addEventListener(MouseEvent.CLICK, clicked);
		}
		
		public function destroy():void
		{
			removeEventListener(MouseEvent.CLICK, clicked);
		}
		
		public function clicked(e:MouseEvent):void
		{
			e.stopPropagation();
			DisplayUtil.view(link.links);
		}
	}
}