/*
 * Copyright (c) 2009 University of Utah and the Flux Group.
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
 
 package protogeni
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import mx.collections.ArrayCollection;
	
	import protogeni.communication.ProtogeniRpcHandler;
	import protogeni.communication.RequestDiscoverResources;
	import protogeni.communication.RequestGetCredential;
	import protogeni.communication.RequestGetKeys;
	import protogeni.communication.RequestListComponents;
	import protogeni.display.DisplayUtil;
	import protogeni.display.ProtogeniMapHandler;
	import protogeni.resources.ComponentManager;
	import protogeni.resources.ComponentManagerCollection;
	import protogeni.resources.PhysicalLink;
	import protogeni.resources.PhysicalNode;
	import protogeni.resources.Slice;
	import protogeni.resources.Sliver;
	import protogeni.resources.User;
	import protogeni.resources.VirtualLink;
	import protogeni.resources.VirtualNode;
	
	// Holds and handles all information regarding ProtoGENI
	public class ProtogeniHandler extends EventDispatcher
	{
		
		[Bindable]
		public var rpcHandler : ProtogeniRpcHandler;
		
		[Bindable]
		public var mapHandler : ProtogeniMapHandler;
		
		[Bindable]
		public var CurrentUser:User;
		
		public var ComponentManagers:ComponentManagerCollection;

		public function ProtogeniHandler()
		{
			rpcHandler = new ProtogeniRpcHandler();
			mapHandler = new ProtogeniMapHandler();
			addEventListener(ProtogeniEvent.COMPONENTMANAGER_CHANGED, mapHandler.drawMap);
			ComponentManagers = new ComponentManagerCollection();
			CurrentUser = new User();
		}
		
		public function clearAll() : void
		{
			ComponentManagers = new ComponentManagerCollection();
		}
		
		public function search(s:String, matchAll:Boolean):Array
		{
			var searchFrom:Array = s.split(' ');
			var results:Array = new Array();
			for each(var cm:ComponentManager in this.ComponentManagers)
			{
				if(Util.findInAny(searchFrom, new Array(cm.Urn, cm.Hrn, cm.Url), matchAll))
					results.push(DisplayUtil.getComponentManagerButton(cm));
				for each(var pn:PhysicalNode in cm.AllNodes)
				{
					if(Util.findInAny(searchFrom, new Array(pn.urn, pn.name), matchAll))
						results.push(DisplayUtil.getPhysicalNodeButton(pn));
				}
				for each(var pl:PhysicalLink in cm.AllLinks)
				{
					//if(pl.urn == s)
					//	results.push(DisplayUtil.getLinkButton((pn));
				}
			}
			
			for each(var slice:Slice in this.CurrentUser.slices)
			{
				if(Util.findInAny(searchFrom, new Array(slice.urn, slice.hrn, slice.uuid), matchAll))
					results.push(DisplayUtil.getSliceButton(slice));
				for each(var sliver:Sliver in slice.slivers)
				{
					//if(sliver.urn == s)
						//results.push(DisplayUtil.getSliverButton();
					for each(var vn:VirtualNode in sliver.nodes)
					{
						//if(vn.urn == s || vn.uuid == s)
							//results.push(DisplayUtil.getVirtualNodeButton());
					}
					for each(var vl:VirtualLink in sliver.links)
					{
						//if(vn.urn == s || vn.uuid == s)
						//results.push(DisplayUtil.getVirtualNodeButton());
					}
				}
			}
			
			//if(this.CurrentUser.uid == s || this.CurrentUser.uuid == s)
				//results.push(DisplayUtil.getLinkButton(this.CurrentUser);
			
			return results;
		}
		
		// EVENTS
		public function dispatchComponentManagerChanged(cm:ComponentManager):void {
			dispatchEvent(new ProtogeniEvent(ProtogeniEvent.COMPONENTMANAGER_CHANGED, cm));
		}
		
		public function dispatchComponentManagersChanged():void {
			dispatchEvent(new ProtogeniEvent(ProtogeniEvent.COMPONENTMANAGERS_CHANGED));
		}
		
		public function dispatchQueueChanged():void {
			dispatchEvent(new ProtogeniEvent(ProtogeniEvent.QUEUE_CHANGED));
		}
		
		public function dispatchUserChanged():void {
			dispatchEvent(new ProtogeniEvent(ProtogeniEvent.USER_CHANGED));
		}
		
		public function dispatchSliceChanged(s:Slice):void {
			dispatchEvent(new ProtogeniEvent(ProtogeniEvent.SLICE_CHANGED, s));
		}
		
		public function dispatchSlicesChanged():void {
			dispatchEvent(new ProtogeniEvent(ProtogeniEvent.SLICES_CHANGED));
		}
	}
}