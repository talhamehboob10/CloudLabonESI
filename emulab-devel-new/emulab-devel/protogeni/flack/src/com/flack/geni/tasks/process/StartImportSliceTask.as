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

package com.flack.geni.tasks.process
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.RspecUtil;
	import com.flack.geni.display.windows.ChooseManagerWindow;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.VirtualLink;
	import com.flack.geni.resources.virt.extensions.stitching.StitchingHop;
	import com.flack.geni.resources.virt.extensions.stitching.StitchingLink;
	import com.flack.geni.resources.virt.extensions.stitching.StitchingPath;
	import com.flack.geni.resources.virt.extensions.stitching.SwitchingCapabilityDescriptor;
	import com.flack.geni.resources.virt.extensions.stitching.SwitchingCapabilitySpecificInfoL2sc;
	import com.flack.geni.resources.virt.extensions.stitching.SwitchingCapabilitySpecificInfoLsc;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.docs.RspecVersion;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	
	import flash.system.System;
	
	import mx.controls.Alert;
	
	/**
	 * Does preliminary checks for importing and adds parse tasks to the parent task
	 * 
	 * @author mstrum
	 * 
	 */
	public final class StartImportSliceTask extends Task
	{
		public var slice:Slice;
		public var rspecString:String;
		public var checkRspec:XML;
		public var defaultManager:GeniManager;
		public var overwrite:Boolean;
		
		/**
		 * 
		 * @param importSlice Slice to import into
		 * @param importRspec RSPEC to import into the slice
		 * @param importManager Manager to default to if a manager isn't listed
		 * @param allowOverwrite Allow the import to happen into an already allocated slice
		 * 
		 */
		public function StartImportSliceTask(importSlice:Slice,
											 importRspec:String,
											 importManager:GeniManager = null,
											 allowOverwrite:Boolean = false)
		{
			super(
				"Prepare import",
				"Prepares the slice and RSPEC for the import",
				"",
				null,
				0,
				0,
				false,
				[importSlice]
			);
			slice = importSlice;
			rspecString = importRspec;
			defaultManager = importManager;
			overwrite = allowOverwrite;
		}
		
		override protected function runStart():void
		{
			var msg:String;
			if(slice.aggregateSlivers.length > 0 && !overwrite)
			{
				msg = "The slice has already been allocated.";
				Alert.show(msg);
				afterError(
					new TaskError(
						msg,
						TaskError.CODE_PROBLEM
					)
				);
				return;
			}
			if(!overwrite && (slice.links.length > 0 || slice.nodes.length > 0))
			{
				msg = "The slice already has resources waiting to be allocated.";
				Alert.show(msg);
				afterError(
					new TaskError(
						msg,
						TaskError.CODE_PROBLEM
					)
				);
				return;
			}
			
			try
			{
				checkRspec = new XML(rspecString);
			}
			catch(e:Error)
			{
				msg = "The document was either not XML or is not formatted correctly!";
				Alert.show(msg);
				afterError(
					new TaskError(
						msg,
						TaskError.CODE_PROBLEM,
						e
					)
				);
				return;
			}
			
			var defaultNamespace:Namespace = checkRspec.namespace();
			var detectedRspecVersion:Number;
			switch(defaultNamespace.uri)
			{
				case RspecUtil.rspec01Namespace:
					detectedRspecVersion = 0.1;
					break;
				case RspecUtil.rspec02Namespace:
				case RspecUtil.rspec02MalformedNamespace:
					detectedRspecVersion = 0.2;
					break;
				case RspecUtil.rspec2Namespace:
					detectedRspecVersion = 2;
					break;
				case RspecUtil.rspec3Namespace:
					detectedRspecVersion = 3;
					break;
				default:
					msg = "Please use a compatible RSPEC. The namespace '"+defaultNamespace.uri+"' was not recognized";
					Alert.show(msg);
					afterError(
						new TaskError(
							msg,
							TaskError.CODE_PROBLEM
						)
					);
					return;
			}
			
			for each(var nodeXml:XML in checkRspec.defaultNamespace::node)
			{
				var managerUrn:String;
				if(detectedRspecVersion < 1)
				{
					if(nodeXml.@component_manager_urn.length() == 1)
						managerUrn = nodeXml.@component_manager_urn;
					else
						managerUrn = nodeXml.@component_manager_uuid;
				}
				else
					managerUrn = nodeXml.@component_manager_id;
				if(managerUrn.length > 0)
				{
					var detectedManager:GeniManager = GeniMain.geniUniverse.managers.getById(managerUrn);
					if(detectedManager == null)
					{
						msg = "Unkown manager referenced: " + managerUrn;
						Alert.show(msg);
						afterError(
							new TaskError(
								msg,
								TaskError.CODE_PROBLEM
							)
						);
						return;
					}
					else if(detectedManager.Status != FlackManager.STATUS_VALID)
					{
						msg = "Known manager referenced (" + managerUrn + "), but manager didn't load successfully. Please restart Flack.";
						Alert.show(msg);
						afterError(
							new TaskError(
								msg,
								TaskError.CODE_PROBLEM
							)
						);
						return;
					}
				}
				else if(defaultManager == null)
				{
					var askForManager:ChooseManagerWindow = new ChooseManagerWindow();
					askForManager.success = preSelectedManager;
					askForManager.ManagersToList = GeniMain.geniUniverse.managers.Valid;
					askForManager.showWindow();
					Alert.show("There were resources detected without a manager selected, please select which manager you would like to use.");
					return;
				}
			}
			
			doImport();
		}
		
		public function preSelectedManager(newManager:GeniManager):void
		{
			if(newManager == null)
			{
				var msg:String = "No default manager selected for resources without assigned manager";
				Alert.show(msg);
				afterError(
					new TaskError(
						msg,
						TaskError.CODE_PROBLEM
					)
				);
			}
			else
			{
				defaultManager = newManager;
				doImport();
			}
		}
		
		public function doImport():void
		{
			var importRspec:Rspec = new Rspec();
			importRspec.type = Rspec.TYPE_REQUEST;
			var defaultNamespace:Namespace = checkRspec.namespace();
			var managersWithResources:Vector.<GeniManager> = new Vector.<GeniManager>();
			switch(defaultNamespace.uri)
			{
				case RspecUtil.rspec01Namespace:
					importRspec.info = new RspecVersion(RspecVersion.TYPE_PROTOGENI, 0.1);
					break;
				case RspecUtil.rspec02Namespace:
				case RspecUtil.rspec02MalformedNamespace:
					importRspec.info = new RspecVersion(RspecVersion.TYPE_PROTOGENI, 0.2);
					break;
				case RspecUtil.rspec2Namespace:
					importRspec.info = new RspecVersion(RspecVersion.TYPE_PROTOGENI, 2);
					break;
				case RspecUtil.rspec3Namespace:
					importRspec.info = new RspecVersion(RspecVersion.TYPE_GENI, 3);
					break;
			}
			
			slice.removeComponents();
			
			// Build up the managers list which have resources
			for each(var nodeXml:XML in checkRspec.defaultNamespace::node)
			{
				var managerUrn:String;
				var useManager:GeniManager;
				if(importRspec.info.version < 1)
				{
					if(nodeXml.@component_manager_urn.length() == 1)
						managerUrn = nodeXml.@component_manager_urn;
					else
						managerUrn = nodeXml.@component_manager_uuid;
				}
				else
					managerUrn = nodeXml.@component_manager_id;
				
				useManager = GeniMain.geniUniverse.managers.getById(managerUrn);
				if(useManager == null && defaultManager != null)
				{
					useManager = defaultManager;
					if(importRspec.info.version < 1)
					{
						nodeXml.@component_manager_urn = defaultManager.id.full;
						nodeXml.@component_manager_uuid = defaultManager.id.full;
					}
					else
					{
						nodeXml.@component_manager_id = defaultManager.id.full;
					}
				}
				
				if(managersWithResources.indexOf(useManager) == -1)
					managersWithResources.push(useManager);
			}
			var stitchingNamespace:Namespace = RspecUtil.stitchingNamespace;
			for each(var stitchingXml:XML in checkRspec.stitchingNamespace::stitching)
			{
				for each(var pathXml:XML in stitchingXml.stitchingNamespace::path)
				{
					for each(var hopXml:XML in pathXml.stitchingNamespace::hop)
					{
						for each(var stitchingLinkXml:XML in hopXml.stitchingNamespace::link)
						{
							var linkId:String = String(stitchingLinkXml.@id);
							var advertisedLink:StitchingLink = GeniMain.geniUniverse.managers.getComponentById(linkId) as StitchingLink;
							if(advertisedLink == null) {
								continue;
							}
							if(managersWithResources.indexOf(advertisedLink.manager) == -1)
								managersWithResources.push(advertisedLink.manager);
						}
					}
				}
			}
			
			addMessage(
				"Importing into " + managersWithResources.length + " manager(s)",
				"Importing into " + managersWithResources.length + " manager(s)",
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
			
			importRspec.document = checkRspec.toXMLString();
			
			// Import at each manager....
			for each(var managerWithResources:GeniManager in managersWithResources)
			{
				var importSliver:AggregateSliver = slice.aggregateSlivers.getByManager(managerWithResources);
				if(importSliver == null)
					importSliver = new AggregateSliver(slice, managerWithResources);
				parent.add(new ParseRequestManifestTask(importSliver, importRspec, false));
			}
			
			afterComplete(false);
		}
		
		override protected function runCleanup():void
		{
			System.disposeXML(checkRspec);
		}
	}
}