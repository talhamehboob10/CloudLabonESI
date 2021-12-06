/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * Copyright (c) 2011-2012 University of Kentucky.
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

package com.flack.geni.plugins.gemini
{
	import com.flack.geni.plugins.Plugin;
	import com.flack.geni.plugins.PluginArea;
	import com.flack.geni.plugins.emulab.EmulabOpenVzSliverType;
	import com.flack.geni.resources.DiskImage;
	import com.flack.geni.resources.ExtensionSpace;
	import com.flack.geni.resources.ExtensionSpaceCollection;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	
	import flash.utils.Dictionary;
	
	public class Gemini implements Plugin
	{
		public function get Title():String { return "Gemini" };
		public function get Area():PluginArea { return new GeminiArea() };

		public static var geminiNamespace:Namespace = new Namespace("gemini", "http://geni.net/resources/rspec/ext/gemini/1");
		
		[Bindable]
		public static var prepared:Boolean = false;
		
		public static var globalImage:DiskImage = null;
		public static var localImage:DiskImage = null;
		public static var geminiSlices:Dictionary = new Dictionary();
		public static var geminiAutoapply:Dictionary = new Dictionary();
		
		public function Gemini()
		{
			super();
		}
		
		public function init():void
		{
			SharedMain.sharedDispatcher.addEventListener(FlackEvent.CHANGED_SLICE, sliceChanged);
			
			var getDiskImages:GetDiskImagesTask = new GetDiskImagesTask();
			getDiskImages.start();
		}
		
		// Once a slice is populated, figure out if it is instrumentized
		public function sliceChanged(e:FlackEvent):void
		{
			var slice:Slice = e.changedObject as Slice;
			// Detect if a slice used gemini extensions when it's loaded.
			if(e.action == FlackEvent.ACTION_POPULATED)
			{
				for each(var  node:VirtualNode in slice.nodes.collection)
				{
					if(node.extensions.spaces != null && node.extensions.spaces.getForNamespace(geminiNamespace) != null)
					{
						geminiSlices[slice.id.full] = true;
						return;
					}
				}
				geminiSlices[slice.id.full] = false;
			}
			else
			{
				if(geminiSlices[slice.id.full] != null && geminiSlices[slice.id.full] == true)
				{
					instrumentizeSlice(slice);
				}
			}
		}
		
		public static function getGlobalNodeFor(slice:Slice, manager:GeniManager):VirtualNode
		{
			var nodes:VirtualNodeCollection = slice.nodes.getByManager(manager);
			var globalNodeExists:Boolean = false;
			for each(var candidate:VirtualNode in nodes.collection)
			{
				if(candidate.extensions.spaces == null)
					continue;
				var geminiExtension:ExtensionSpace = candidate.extensions.spaces.getForNamespace(geminiNamespace);
				if(geminiExtension == null)
					continue;
				if(String(geminiExtension.children[0].@type) == "global_node")
				{
					return candidate;
				}
			}
			return null;
		}
		
		public static function makeGlobalNodeFor(slice:Slice, manager:GeniManager):VirtualNode
		{
			var globalNode:VirtualNode = new VirtualNode(
				slice,
				manager,
				manager.makeValidClientIdFor(slice.getUniqueId(null, "GN")),
				false,
				"emulab-openvz");
			globalNode.emulabRoutableControlIp = true;
			globalNode.sliverType.selectedImage = new DiskImage();
			if(manager.id.authority == globalImage.id.authority)
				globalNode.sliverType.selectedImage.id.full = globalImage.id.full;
			else
				globalNode.sliverType.selectedImage.url = globalImage.url;
			globalNode.extensions.spaces = new ExtensionSpaceCollection();
			var geminiExtensionSpace:ExtensionSpace = new ExtensionSpace();
			geminiExtensionSpace.namespace = geminiNamespace;
			geminiExtensionSpace.children.push(new XML(
				"<node type=\"global_node\" xmlns=\"http://geni.net/resources/rspec/ext/gemini/1\"><monitor_urn name=\"" + manager.id.full + "\"/></node>"));
			globalNode.extensions.spaces.add(geminiExtensionSpace);
			return globalNode;
		}
		
		public static function deinstrumentizeSlice(slice:Slice):void
		{
			var changed:Boolean = false;
			// Delete any global nodes.
			var managers:GeniManagerCollection = slice.nodes.Managers;
			for each(var manager:GeniManager in managers.collection)
			{
				var globalNode:VirtualNode = getGlobalNodeFor(slice, manager);
				if(globalNode != null)
				{
					changed = true;
					globalNode.removeFromSlice();
				}
			}
			
			// Remove gemini from normal nodes.
			for each(var node:VirtualNode in slice.nodes.collection)
			{
				if(node.extensions.spaces == null)
					continue;
				var geminiExtension:ExtensionSpace = node.extensions.spaces.getForNamespace(geminiNamespace);
				if(geminiExtension != null)
				{
					changed = true;
					node.extensions.spaces.remove(geminiExtension);
					if(node.sliverType.name == EmulabOpenVzSliverType.TYPE_EMULABOPENVZ)
					{
						if(node.sliverType.selectedImage != null)
						{
							if(node.sliverType.selectedImage.id.full == localImage.id.full)
								node.sliverType.selectedImage.id.full = "";
							else if(node.sliverType.selectedImage.url == localImage.url)
								node.sliverType.selectedImage.url = "";
						}
					}
				}
			}
			
			if(changed)
			{
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					slice,
					FlackEvent.ACTION_CHANGED
				);
			}
		}
		
		public static function instrumentizeSlice(slice:Slice):void
		{
			var changed:Boolean = false;
			// Make sure normal nodes have the extension.
			for each(var node:VirtualNode in slice.nodes.collection)
			{
				if(node.extensions.spaces == null)
					node.extensions.spaces = new ExtensionSpaceCollection();
				if(node.extensions.spaces.getForNamespace(geminiNamespace) == null)
				{
					changed = true;
					var extensionSpace:ExtensionSpace = new ExtensionSpace();
					extensionSpace.namespace = geminiNamespace;
					extensionSpace.children.push(new XML(
					"<node type=\"mp_node\" xmlns=\"http://geni.net/resources/rspec/ext/gemini/1\"><services><active install=\"yes\" enable=\"yes\"/><passive install=\"yes\" enable=\"yes\"/></services></node>"));
					node.extensions.spaces.add(extensionSpace);
				}
				if(node.sliverType.name == EmulabOpenVzSliverType.TYPE_EMULABOPENVZ)
				{
					if(node.sliverType.selectedImage == null)
						node.sliverType.selectedImage = new DiskImage();
					if(node.sliverType.selectedImage.id.full.length == 0 && node.sliverType.selectedImage.url.length == 0)
					{
						changed = true;
						if(node.manager.id.authority == localImage.id.authority)
							node.sliverType.selectedImage.id.full = localImage.id.full;
						else
							node.sliverType.selectedImage.url = localImage.url;
					}
				}
			}
			
			// At this point, all nodes should have the gemini extension.
			// Add any missing global nodes.
			// Remove any global nodes which aren't needed anymore.
			var managers:GeniManagerCollection = slice.nodes.Managers;
			for each(var manager:GeniManager in managers.collection)
			{
				var globalNode:VirtualNode = getGlobalNodeFor(slice, manager);
				if(globalNode == null)
				{
					changed = true;
					slice.nodes.add(makeGlobalNodeFor(slice, manager));
				}
				else if(slice.nodes.getByManager(manager).length == 1)
				{
					changed = true;
					globalNode.removeFromSlice();
				}
			}
			
			if(changed)
			{
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					slice,
					FlackEvent.ACTION_CHANGED
				);
			}
		}
	}
}
