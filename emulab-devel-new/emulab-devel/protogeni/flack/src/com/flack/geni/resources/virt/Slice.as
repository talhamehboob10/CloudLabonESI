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

package com.flack.geni.resources.virt
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.GeniUser;
	import com.flack.geni.resources.docs.GeniCredential;
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.extensions.SliceFlackInfo;
	import com.flack.geni.resources.virt.extensions.slicehistory.SliceHistory;
	import com.flack.geni.resources.virt.extensions.slicehistory.SliceHistoryItem;
	import com.flack.geni.resources.virt.extensions.stitching.RequestStitching;
	import com.flack.geni.tasks.groups.slice.ImportSliceTaskGroup;
	import com.flack.geni.tasks.process.GenerateRequestManifestTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.resources.IdentifiableObject;
	import com.flack.shared.resources.docs.RspecVersion;
	import com.flack.shared.utils.DateUtil;
	
	import flash.globalization.DateTimeFormatter;
	import flash.globalization.DateTimeStyle;
	import flash.globalization.LocaleID;

	/**
	 * Container for slivers
	 * 
	 * @author mstrum
	 * 
	 */
	public class Slice extends IdentifiableObject
	{
		[Bindable]
		public var hrn:String = "";
		public function get Name():String
		{
			if(id != null)
				return id.name;
			else if(hrn != null)
				return hrn;
			else
				return "";
		}
		
		public var creator:GeniUser = null;
		public var authority:GeniAuthority = null;
		public var credential:GeniCredential = null;
		// A slice is considered instantiated if a credential exists for it.
		public function get Instantiated():Boolean
		{
			return credential != null && credential.Raw.length > 0;
		}
		
		public var flackInfo:SliceFlackInfo = new SliceFlackInfo();
		// This is only the managers listed by a slice authority, which may have managers missing.
		// For example, ProtoGENI SAs don't list managers outside of the ProtoGENI federation.
		public var reportedManagers:GeniManagerCollection = new GeniManagerCollection();
		public var description:String = "";
		
		public var aggregateSlivers:AggregateSliverCollection = new AggregateSliverCollection();
		public function get RelatedItems():Array
		{
			var results:Array = [this];
			for each(var sliver:AggregateSliver in aggregateSlivers.collection)
				results.push(sliver);
			return results;
		}
		
		public var nodes:VirtualNodeCollection = new VirtualNodeCollection();
		public var links:VirtualLinkCollection = new VirtualLinkCollection();
		public function get Components():VirtualComponentCollection
		{
			var components:VirtualComponentCollection = new VirtualComponentCollection();
			components.addAll(nodes.collection);
			components.addAll(links.collection);
			return components;
		}
		
		public var stitching:RequestStitching = new RequestStitching();
		
		// Note this is the slice container expiration.
		public var expires:Date = null;
		/**
		 * 
		 * @return Earliest expiration for anything in the slice.
		 * 
		 */
		public function get EarliestExpiration():Date
		{
			var earliestComponentExpiration:Date = Components.EarliestExpiration;
			if(earliestComponentExpiration == null)
				return expires;
			if(expires == null)
				return null;
			if(earliestComponentExpiration < expires)
				return earliestComponentExpiration;
			return expires;
		}
		public function get ExpiresString():String
		{
			var dateFormatter:DateTimeFormatter = new DateTimeFormatter(LocaleID.DEFAULT, DateTimeStyle.SHORT, DateTimeStyle.NONE);
			var result:String = "";
			if(expires != null)
			{
				if(aggregateSlivers != null)
				{
					var earliestComponentExpiration:Date = Components.EarliestExpiration;
					if(earliestComponentExpiration != null && earliestComponentExpiration.time < expires.time)
					{
						result = "Sliver expires before slice in\n\t"
							+ DateUtil.getTimeUntil(earliestComponentExpiration)
							+ "\n\ton "
							+ dateFormatter.format(earliestComponentExpiration)
							+ "\n\n";
					}
				}
				
				result += "Slice expires in\n\t"
					+ DateUtil.getTimeUntil(expires)
					+ "\n\ton "
					+ dateFormatter.format(expires);
			}
			else
				result = "No expiration date yet";
			
			return result;
		}
		
		public function get UnsubmittedChanges():Boolean
		{
			for each(var sliver:AggregateSliver in aggregateSlivers.collection)
			{
				if(sliver.UnsubmittedChanges)
					return true;
			}
			if(Components.UnsubmittedChanges)
				return true;
			return false;
		}
		
		[Bindable]
		public var useInputRspecInfo:RspecVersion = GeniMain.usableRspecVersions.MaxVersion;
		
		// Flack extension
		public var history:SliceHistory = new SliceHistory();
		
		/**
		 * 
		 * @param id IDN-URN
		 * 
		 */
		public function Slice(id:String = "")
		{
			super(id);
		}
		
		public function pushState():void
		{
			// Don't push an empty state
			if(nodes.length == 0 && links.length == 0)
				return;
			
			// Remove any redo history
			if(history.backIndex < history.states.length-1)
				history.states.splice(history.backIndex+1, history.states.length - history.backIndex - 1);
			
			var oldHistory:SliceHistory = history;
			
			var getRspec:GenerateRequestManifestTask = new GenerateRequestManifestTask(this, false, false, false);
			getRspec.start();
			
			oldHistory.states.push(
				new SliceHistoryItem(
					getRspec.resultRspec.document,
					history.stateName
				)
			);
			if(oldHistory.states.length > 20)
			{
				oldHistory.states.splice(0, oldHistory.states.length - 20);
			}
			oldHistory.backIndex = history.states.length-1;
			history = oldHistory;
			history.stateName = "";
			
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLICE,
				this
			);
		}
		
		public function get CanGoBack():Boolean
		{
			return history.backIndex > -1 || nodes.length > 0;
		}
		
		public function get CanGoForward():Boolean
		{
			return history.backIndex < history.states.length-1;
		}
		
		public function backState():String
		{
			// Save the state to return in case user wants to redo
			var oldRspec:String = "";
			if(CanGoBack)
			{
				var saveRspec:GenerateRequestManifestTask = null;
				if(aggregateSlivers.length > 0)
					saveRspec = new GenerateRequestManifestTask(aggregateSlivers.collection[0], false, false, false, false, useInputRspecInfo);
				else
					saveRspec = new GenerateRequestManifestTask(this, false, false, false, false, useInputRspecInfo);
				saveRspec.start();
				
				history.states.splice(history.backIndex+1, 0,
					new SliceHistoryItem(
						saveRspec.resultRspec.document,
						history.stateName
					)
				);
				
				oldRspec = saveRspec.resultRspec.document;
				
				if(history.backIndex > -1)
				{
					var oldHistory:SliceHistory = history;
					var restoreHistoryItem:SliceHistoryItem = history.states.slice(history.backIndex, history.backIndex+1)[0];
					
					var importRspec:ImportSliceTaskGroup = new ImportSliceTaskGroup(this, restoreHistoryItem.rspec, null, true);
					importRspec.start();
					
					// Remove old state which is now the current state
					oldHistory.states.splice(oldHistory.backIndex, 1);
					oldHistory.stateName = restoreHistoryItem.note;
					oldHistory.backIndex--;
					history = oldHistory;
				}
				else
				{
					removeComponents();
					aggregateSlivers.cleanup();
					for each(var sliver:AggregateSliver in this.aggregateSlivers.collection)
						sliver.UnsubmittedChanges = true;
				}
			}
			
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_SLICE,
				this
			);
			
			return oldRspec;
		}
		
		public function forwardState():String
		{
			if(history.backIndex < history.states.length-1)
			{
				var oldHistory:SliceHistory = history;
				var restoreHistoryItem:SliceHistoryItem = history.states.slice(history.backIndex+1, history.backIndex+2)[0];
				
				// Save the state to return in case user wants to undo
				var saveRspec:GenerateRequestManifestTask = null;
				if(aggregateSlivers.length > 0)
					saveRspec = new GenerateRequestManifestTask(aggregateSlivers.collection[0], false, false, false, false, useInputRspecInfo);
				else
					saveRspec = new GenerateRequestManifestTask(this, false, false, false, false, useInputRspecInfo);
				saveRspec.start();
				
				// Save current state into history for undo
				oldHistory.states.splice(history.backIndex+1, 0,
					new SliceHistoryItem(
						saveRspec.resultRspec.document,
						history.stateName
					)
				);
				
				var importRspec:ImportSliceTaskGroup = new ImportSliceTaskGroup(this, restoreHistoryItem.rspec, null, true);
				importRspec.start();
				
				// Remove old state which is now the current state
				oldHistory.states.splice(oldHistory.backIndex+2, 1);
				oldHistory.stateName = restoreHistoryItem.note;
				oldHistory.backIndex++;
				history = oldHistory;
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					this
				);
				
				return saveRspec.resultRspec.document
			}
			else
				return "";
		}
		
		public function resetStatus():void
		{
			for each(var statusNode:VirtualNode in nodes.collection)
			{
				statusNode.clearState();
				var nodeAggregateSliver:AggregateSliver = aggregateSlivers.getByManager(statusNode.manager);
				if(nodeAggregateSliver != null)
				{
					var nodeSliver:Sliver = nodeAggregateSliver.idsToSlivers[statusNode.id.full];
					if(nodeSliver != null)
						statusNode.copyFrom(nodeSliver);
				}
			}
			for each(var statusLink:VirtualLink in links.collection)
			{
				statusLink.clearState();
				var linkSlivers:AggregateSliverCollection = aggregateSlivers.getByManagers(statusLink.interfaceRefs.Interfaces.Managers);
				if(linkSlivers.length > 0)
				{
					var linkSliver:Sliver = linkSlivers.collection[0].idsToSlivers[statusLink.id.full];
					if(nodeSliver != null)
						statusLink.copyFrom(linkSliver);
				}
			}
		}
		
		public function getBySliverId(sliverId:String):*
		{
			var obj:* = nodes.getById(sliverId);
			if(obj != null) return obj;
			obj = nodes.getInterfaceBySliverId(sliverId);
			if(obj != null) return obj;
			obj = links.getById(sliverId);
			if(obj != null) return obj;
			if(id.full == sliverId) return this;
			obj = aggregateSlivers.getBySliverId(sliverId);
			if(obj != null) return obj;
			return null;
		}
		
		public function getByClientId(clientId:String):*
		{
			var obj:* = nodes.getByClientId(clientId);
			if(obj != null) return obj;
			obj = nodes.getInterfaceByClientId(clientId);
			if(obj != null) return obj;
			obj = links.getByClientId(clientId);
			if(obj != null) return obj;
			return null;
		}
		
		public function isIdUnique(obj:*, testId:String):Boolean
		{
			var result:* = nodes.getByClientId(testId);
			if(result != null && result != obj)
				return false;
			result = links.getByClientId(testId);
			if(result != null && result != obj)
				return false;
			return true;
		}
		
		public function getUniqueId(obj:*, base:String, start:int = 0):String
		{
			var start:int = start;
			var highest:int = start;
			while(!links.isIdUnique(obj, base + highest))
				highest++;
			while(!nodes.isIdUnique(obj, base + highest))
				highest++;
			if(id.full == base + highest)
				highest++;
			if(highest > start)
				return getUniqueId(obj, base, highest);
			else
				return base + highest;
		}
		
		public function get AllocationState():String
		{
			return aggregateSlivers.AllocationState;
		}
		public function get OperationalState():String
		{
			return aggregateSlivers.OperationalState;
		}

		public function get Managers():GeniManagerCollection
		{
			var managers:GeniManagerCollection = nodes.Managers;
			var stitchingManagers:GeniManagerCollection = stitching.Managers;
			for each(var stitchingManager:GeniManager in stitchingManagers.collection)
			{
				if(!managers.contains(stitchingManager))
				{
					managers.add(stitchingManager);
				}
			}
			return managers;
		}
		
		public function clearStatus():void
		{
			for each(var sliver:AggregateSliver in aggregateSlivers.collection)
				sliver.clearStates();
			
			Components.clearStates();
		}
		
		/**
		 * Removes manifests/sliver_ids from components and clears states.
		 * 
		 * Slivers still have manifests to indicate they were created.
		 * 
		 */
		public function markStaged():void
		{
			for each(var sliver:AggregateSliver in aggregateSlivers.collection)
				sliver.markStaged();
				
			Components.markStaged();
		}
		
		public function ensureSliversExist():void
		{
			for each(var manager:GeniManager in this.Managers.collection)
				aggregateSlivers.getOrCreateByManager(manager, this);
		}
		
		/**
		 * Removes everything from the slice
		 * 
		 */
		public function removeAll():void
		{
			history = new SliceHistory();
			aggregateSlivers = new AggregateSliverCollection();
			reportedManagers = new GeniManagerCollection();
			removeComponents();
		}
		
		public function removeComponents():void
		{
			nodes = new VirtualNodeCollection();
			links = new VirtualLinkCollection();
			stitching = new RequestStitching();
		}
		
		public function removeComponentById(id:String):void
		{
			var foundObject:IdentifiableObject = nodes.getById(id);
			if(foundObject != null)
			{
				nodes.remove(foundObject);
				return;
			}
			
			foundObject = links.getById(id);
			if(foundObject != null)
			{
				links.remove(foundObject);
			}
		}
		
		override public function toString():String
		{
			var result:String = "[Slice ID="+id.full+"]\n";
			for each(var sliver:AggregateSliver in aggregateSlivers.collection)
				result += "\t"+sliver.toString() + "\n";
			for each(var node:VirtualNode in nodes.collection)
				result += "\t"+node.toString() + "\n";
			for each(var link:VirtualLink in links.collection)
				result += "\t"+link.toString() + "\n";
			result += "\t[History States=\""+history.states.length+"\" /]\n";
			return result+"[/Slice]";
		}
	}
}