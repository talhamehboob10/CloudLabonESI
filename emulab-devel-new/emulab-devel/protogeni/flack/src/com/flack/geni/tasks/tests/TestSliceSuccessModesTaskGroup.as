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

package com.flack.geni.tasks.tests 
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.plugins.emulab.RawPcSliverType;
	import com.flack.geni.resources.Property;
	import com.flack.geni.resources.SliverTypes;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.VirtualInterface;
	import com.flack.geni.resources.virt.VirtualLink;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	import com.flack.geni.tasks.groups.slice.CreateSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.ImportSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.RenewSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.RestartSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.StartSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.StopSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.SubmitSliceTaskGroup;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskEvent;
	
	/**
	 * Runs a series of tests to see if the code for working with slices is correct
	 * 
	 * @author mstrum
	 * 
	 */
	public final class TestSliceSuccessModesTaskGroup extends TestTaskGroup
	{
		public function TestSliceSuccessModesTaskGroup()
		{
			super(
				"Test successful slice ops",
				"Tests to make sure all code dealing with successful slice operations is correct"
			);
		}
		
		override protected function startTest():void
		{
			addTest(
				"Good slice name",
				new CreateSliceTaskGroup(
					"test" + Math.floor(Math.random()*1000000),
					GeniMain.geniUniverse.user.authority
				), 
				firstSliceCreated
			);
		}
		
		// Import slice from RSPEC
		public function firstSliceCreated(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				
				addTest(
					"Import RSPEC",
					new ImportSliceTaskGroup(
						(event.task as CreateSliceTaskGroup).newSlice,
						(new TestsliceRspec()).toString()),
					firstSliceImported
				);
			}
		}
		
		// 3b. Check
		// 4a. Submit
		public function firstSliceImported(event:TaskEvent):void
		{
			var slice:Slice = (event.task as ImportSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				addMessage(
					"Imported Slice details",
					slice.toString()
				);
				
				// Test the imported slice to make sure it mirrors the RSPEC
				var testInterface:VirtualInterface;
				var errorFound:Boolean = false;
				// Make sure the slivers are okay
				if(slice.aggregateSlivers.length != 2)
				{
					errorFound = true;
					addMessage(
						"Incorrect slivers",
						"Found " + slice.aggregateSlivers.length + " slivers instead of 2",
						LogMessage.LEVEL_FAIL
					);
				}
				
				var testName:String = "utahemulab.cm";
				var testSliver:AggregateSliver = slice.aggregateSlivers.getByManager(GeniMain.geniUniverse.managers.getByHrn(testName));
				if(testSliver == null)
				{
					errorFound = true;
					addMessage(
						"Sliver not found",
						"Didn't find sliver on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				
				testSliver = slice.aggregateSlivers.getByManager(GeniMain.geniUniverse.managers.getByHrn("ukgeni.cm"));
				if(testSliver == null)
				{
					errorFound = true;
					addMessage(
						"Sliver not found",
						"Didn't find sliver on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				
				// Make sure the nodes are okay
				if(slice.nodes.length != 2)
				{
					errorFound = true;
					addMessage(
						"Incorrect number of nodes",
						"Found " + slice.aggregateSlivers.length + " node(s) instead of 2",
						LogMessage.LEVEL_FAIL
					);
				}
				testName = "exclusive-0";
				var testNode:VirtualNode = slice.nodes.getNodeByClientId(testName);
				if(testNode == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find node named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testNode.manager.hrn != "utahemulab.cm")
					{
						errorFound = true;
						addMessage(
							"Wrong manager for " + testName,
							"Node " + testName + " was found to be on " + testNode.manager.hrn,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.sliverType.selectedImage.id.full != "urn:publicid:IDN+emulab.net+image+emulab-ops//FEDORA10-STD")
					{
						errorFound = true;
						addMessage(
							"Wrong disk_image found found for " + testName,
							"Found wrong disk image: " + testNode.sliverType.selectedImage.id.full,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.interfaces.length != 1)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interfaces on " + testName,
							testName + " has " + testNode.interfaces.length + " interfaces",
							LogMessage.LEVEL_FAIL
						);
					}
					var testSubName:String = "exclusive-0:if1";
					testInterface = testNode.interfaces.getByClientId(testSubName);
					if(testInterface == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					else if(testInterface.ip.address != "192.168.0.1")
					{
						errorFound = true;
						addMessage(
							"Didn't find correct IP address on " + testSubName,
							"Expecting to find 192.168.0.1, found " + testInterface.ip.address,
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testNode.flackInfo.x != 192)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackX on " + testName,
							"Expected 192, found " + testNode.flackInfo.x,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.y != 51)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackY on " + testName,
							"Expected 51, found " + testNode.flackInfo.y,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.unbound == false)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackUnbound on " + testName,
							"Expected true, found false",
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				testName = "exclusive-1";
				testNode = slice.nodes.getNodeByClientId(testName);
				if(testNode == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find node named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testNode.manager.hrn != "ukgeni.cm")
					{
						errorFound = true;
						addMessage(
							"Wrong manager for " + testName,
							"Node " + testName + " was found to be on " + testNode.manager.hrn,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.interfaces.length != 1)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interfaces on " + testName,
							testName + " has " + testNode.interfaces.length + " interfaces",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-1:if1";
					testInterface = testNode.interfaces.getByClientId(testSubName);
					if(testInterface == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					else if(testInterface.ip.address != "192.168.0.2")
					{
						errorFound = true;
						addMessage(
							"Didn't find correct IP address on " + testSubName,
							"Expecting to find 192.168.0.2, found " + testInterface.ip.address,
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testNode.flackInfo.x != 294)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackX on " + testName,
							"Expected 294, found " + testNode.flackInfo.x,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.y != 182)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackY on " + testName,
							"Expected 182, found " + testNode.flackInfo.y,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.unbound == false)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackUnbound on " + testName,
							"Expected true, found false",
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				// Make sure the links are okay
				if(slice.links.length != 1)
				{
					errorFound = true;
					addMessage(
						"Incorrect links",
						"Found " + slice.aggregateSlivers.length + " links instead of 1",
						LogMessage.LEVEL_FAIL
					);
				}
				testName = "link-0";
				var testLink:VirtualLink = slice.links.getLinkByClientId(testName);
				if(testLink == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find link named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testLink.interfaceRefs.length != 2)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interface refs on " + testName,
							testName + " has " + testLink.interfaceRefs.length + " interface refs",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-0:if1";
					var testInterfaceLeft:VirtualInterface = testLink.interfaceRefs.Interfaces.getByClientId(testSubName);
					if(testInterfaceLeft == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface ref " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-1:if1";
					var testInterfaceRight:VirtualInterface = testLink.interfaceRefs.Interfaces.getByClientId(testSubName);
					if(testInterfaceRight == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface fref " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testLink.properties.length != 2)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of properties on " + testName,
							testName + " has " + testLink.properties.length + " properties",
							LogMessage.LEVEL_FAIL
						);
					}
					var testProperty:Property = testLink.properties.getFor(testInterfaceRight, testInterfaceLeft);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceLeft.clientId,
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceLeft.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceLeft, testInterfaceRight);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceRight.clientId,
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceRight.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				// Problem after parsing the manifests...
				if(errorFound)
				{
					testFailed("Inconsistencies found in the imported slice compared to the RSPEC which was imported!");
					return;
				}
				
				testSucceeded();
				
				addTest(
					"Submit slice",
					new SubmitSliceTaskGroup(slice, false), 
					firstSliceSubmitted
				);
			}
		}
		
		// 4b. Check
		// 5a. Renew
		private var preRenewExpire:Date;
		public function firstSliceSubmitted(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				addMessage(
					"Slice details post-submit",
					slice.toString()
				);
				
				// Check to make sure the slice parsed from the manifests mirrors what is expected
				var testInterface:VirtualInterface;
				var errorFound:Boolean = false;
				// Make sure the slivers are okay
				if(slice.aggregateSlivers.length != 2)
				{
					errorFound = true;
					addMessage(
						"Incorrect slivers",
						"Found " + slice.aggregateSlivers.length + " slivers instead of 2",
						LogMessage.LEVEL_FAIL
					);
				}
				
				var testName:String = "utahemulab.cm";
				var testSliver:AggregateSliver = slice.aggregateSlivers.getByManager(GeniMain.geniUniverse.managers.getByHrn(testName));
				if(testSliver == null)
				{
					errorFound = true;
					addMessage(
						"Sliver not found",
						"Didn't find sliver on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else if(testSliver.manifest.document.length == 0)
				{
					errorFound = true;
					addMessage(
						"Sliver manifest not found",
						"Didn't find manifest on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				
				testSliver = slice.aggregateSlivers.getByManager(GeniMain.geniUniverse.managers.getByHrn("ukgeni.cm"));
				if(testSliver == null)
				{
					errorFound = true;
					addMessage(
						"Sliver not found",
						"Didn't find sliver on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else if(testSliver.manifest.document.length == 0)
				{
					errorFound = true;
					addMessage(
						"Sliver manifest not found",
						"Didn't find manifest on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				
				// Make sure the nodes are okay
				if(slice.nodes.length != 2)
				{
					errorFound = true;
					addMessage(
						"Incorrect number of nodes",
						"Found " + slice.aggregateSlivers.length + " node(s) instead of 2",
						LogMessage.LEVEL_FAIL
					);
				}
				testName = "exclusive-0";
				var testNode:VirtualNode = slice.nodes.getNodeByClientId(testName);
				if(testNode == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find node named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testNode.manifest.length == 0)
					{
						errorFound = true;
						addMessage(
							"Manifest not found for " + testName,
							"Didn't find manifest on " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.manager.hrn != "utahemulab.cm")
					{
						errorFound = true;
						addMessage(
							"Wrong manager for " + testName,
							"Node " + testName + " was found to be on " + testNode.manager.hrn,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.sliverType.selectedImage.id.full != "urn:publicid:IDN+emulab.net+image+emulab-ops//FEDORA10-STD")
					{
						errorFound = true;
						addMessage(
							"Wrong disk_image found found for " + testName,
							"Found wrong disk image: " + testNode.sliverType.selectedImage.id.full,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.Physical == null)
					{
						errorFound = true;
						addMessage(
							"No physical node found for " + testName,
							"No physical node found for " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					else if(testNode.Physical.hardwareTypes.getByName("pc3000") == null)
					{
						errorFound = true;
						addMessage(
							"Hardware_type mismatch found for " + testName,
							testName + " is not of type pc3000",
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.interfaces.length != 1)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interfaces on " + testName,
							testName + " has " + testNode.interfaces.length + " interfaces",
							LogMessage.LEVEL_FAIL
						);
					}
					var testSubName:String = "exclusive-0:if1";
					testInterface = testNode.interfaces.getByClientId(testSubName);
					if(testInterface == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					else if(testInterface.ip.address != "192.168.0.1")
					{
						errorFound = true;
						addMessage(
							"Didn't find correct IP address on " + testSubName,
							"Expecting to find 192.168.0.1, found " + testInterface.ip.address,
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testNode.flackInfo.x != 192)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackX on " + testName,
							"Expected 192, found " + testNode.flackInfo.x,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.y != 51)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackY on " + testName,
							"Expected 51, found " + testNode.flackInfo.y,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.unbound == false)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackUnbound on " + testName,
							"Expected true, found false",
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				testName = "exclusive-1";
				testNode = slice.nodes.getNodeByClientId(testName);
				if(testNode == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find node named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testNode.manifest.length == 0)
					{
						errorFound = true;
						addMessage(
							"Manifest not found for " + testName,
							"Didn't find manifest on " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.manager.hrn != "ukgeni.cm")
					{
						errorFound = true;
						addMessage(
							"Wrong manager for " + testName,
							"Node " + testName + " was found to be on " + testNode.manager.hrn,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.Physical == null)
					{
						errorFound = true;
						addMessage(
							"No physical node found for " + testName,
							"No physical node found for " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.interfaces.length != 1)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interfaces on " + testName,
							testName + " has " + testNode.interfaces.length + " interfaces",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-1:if1";
					testInterface = testNode.interfaces.getByClientId(testSubName);
					if(testInterface == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					else if(testInterface.ip.address != "192.168.0.2")
					{
						errorFound = true;
						addMessage(
							"Didn't find correct IP address on " + testSubName,
							"Expecting to find 192.168.0.2, found " + testInterface.ip.address,
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testNode.flackInfo.x != 294)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackX on " + testName,
							"Expected 294, found " + testNode.flackInfo.x,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.y != 182)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackY on " + testName,
							"Expected 182, found " + testNode.flackInfo.y,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.unbound == false)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackUnbound on " + testName,
							"Expected true, found false",
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				// Make sure the links are okay
				if(slice.links.length != 1)
				{
					errorFound = true;
					addMessage(
						"Incorrect links",
						"Found " + slice.aggregateSlivers.length + " links instead of 1",
						LogMessage.LEVEL_FAIL
					);
				}
				testName = "link-0";
				var testLink:VirtualLink = slice.links.getLinkByClientId(testName);
				if(testLink == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find link named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testLink.interfaceRefs.length != 2)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interface refs on " + testName,
							testName + " has " + testLink.interfaceRefs.length + " interface refs",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-0:if1";
					var testInterfaceLeft:VirtualInterface = testLink.interfaceRefs.Interfaces.getByClientId(testSubName);
					if(testInterfaceLeft == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface ref " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-1:if1";
					var testInterfaceRight:VirtualInterface = testLink.interfaceRefs.Interfaces.getByClientId(testSubName);
					if(testInterfaceRight == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface fref " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testLink.properties.length != 2)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of properties on " + testName,
							testName + " has " + testLink.properties.length + " properties",
							LogMessage.LEVEL_FAIL
						);
					}
					var testProperty:Property = testLink.properties.getFor(testInterfaceRight, testInterfaceLeft);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceLeft.clientId,
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceLeft.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceLeft, testInterfaceRight);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceRight.clientId,
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceRight.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				// Problem after parsing the manifests...
				if(errorFound)
				{
					testFailed("Inconsistencies found in the allocated slice compared to the requested slice!");
					return;
				}
				
				testSucceeded();
				
				preRenewExpire = slice.expires;
				var newExpires:Date = new Date();
				newExpires.time = slice.expires.time + 1000*60*60; // 1 more hour
				
				addTest(
					"Renew slice",
					new RenewSliceTaskGroup(slice, newExpires), 
					firstSliceRenewed
				);
			}
		}
		
		// 5b. Check
		// 6a. Stop
		public function firstSliceRenewed(event:TaskEvent):void
		{
			var slice:Slice = (event.task as RenewSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				if(preRenewExpire == slice.expires)
				{
					testFailed("Slice renew failed");
					return;
				}
				if(preRenewExpire == slice.aggregateSlivers.EarliestExpiration)
				{
					testFailed("Sliver renew failed");
					return;
				}
				
				testSucceeded();
				
				addTest(
					"Stop slice",
					new StopSliceTaskGroup(slice), 
					firstSliceStopped
				);
			}
		}
		
		// 6b. Check
		// 7a. Start
		public function firstSliceStopped(event:TaskEvent):void
		{
			var slice:Slice = (event.task as StopSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				
				addTest(
					"Start slice",
					new StartSliceTaskGroup(slice), 
					firstSliceStarted
				);
			}
		}
		
		// 7b. Check
		// 8a. Restart
		public function firstSliceStarted(event:TaskEvent):void
		{
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				
				addTest(
					"Restart slice",
					new RestartSliceTaskGroup((event.task as StartSliceTaskGroup).slice), 
					firstSliceRestarted
				);
			}
		}
		
		// 8b. Check
		// 9a. Update, adding more utah nodes and a LAN
		public function firstSliceRestarted(event:TaskEvent):void
		{
			var slice:Slice = (event.task as RestartSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				testSucceeded();
				
				addMessage(
					"Preparing Step #" + NextStepNumber,
					"Changing the slice"
				);
				
				// Add two utah nodes and connect all three on the same link
				var utahNode1:VirtualNode = new VirtualNode(
					slice,
					GeniMain.geniUniverse.managers.getByHrn("utahemulab.cm"),
					"test0",
					true,
					RawPcSliverType.TYPE_RAWPC_V2
				);
				slice.nodes.add(utahNode1);
				var utahNode2:VirtualNode = new VirtualNode(
					slice,
					GeniMain.geniUniverse.managers.getByHrn("utahemulab.cm"),
					"test1",
					true,
					RawPcSliverType.TYPE_RAWPC_V2
				);
				slice.nodes.add(utahNode2);
				
				var utahLink:VirtualLink = new VirtualLink(slice);
				if(utahLink.establish(slice.nodes.getByManager(utahNode1.manager)))
				{
					testFailed("Unable to create link in code!");
					return;
				}
				else
				{
					utahLink.clientId = "lan";
					slice.links.add(utahLink);
					
					addMessage(
						"Slice details post-add",
						slice.toString()
					);
					
					// Quick sanity check
					if(utahLink.interfaceRefs.length != 3)
					{
						testFailed("Link should have 3 interface refs, has " + utahLink.interfaceRefs.length + "!");
						return;
					}
					
					addTest(
						"",
						new SubmitSliceTaskGroup(slice, false),
						firstSliceUpdatedWithMore
					);
				}
			}
		}
		
		// 9b. Check
		// 10a. Update removing all but one utah node
		public function firstSliceUpdatedWithMore(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Success != Success");
			else
			{
				addMessage(
					"Slice details post-add-update",
					slice.toString()
				);
				
				// Check to make sure the slice parsed from the manifests mirrors what is expected
				var testInterface:VirtualInterface;
				var testInterfaceLeft:VirtualInterface;
				var testInterfaceRight:VirtualInterface;
				var testProperty:Property;
				var errorFound:Boolean = false;
				// Make sure the slivers are okay
				if(slice.aggregateSlivers.length != 2)
				{
					errorFound = true;
					addMessage(
						"Incorrect slivers",
						"Found " + slice.aggregateSlivers.length + " slivers instead of 2",
						LogMessage.LEVEL_FAIL
					);
				}
				
				var testName:String = "utahemulab.cm";
				var testSliver:AggregateSliver = slice.aggregateSlivers.getByManager(GeniMain.geniUniverse.managers.getByHrn(testName));
				if(testSliver == null)
				{
					errorFound = true;
					addMessage(
						"Sliver not found",
						"Didn't find sliver on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else if(testSliver.manifest.document.length == 0)
				{
					errorFound = true;
					addMessage(
						"Sliver manifest not found",
						"Didn't find manifest on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				
				testSliver = slice.aggregateSlivers.getByManager(GeniMain.geniUniverse.managers.getByHrn("ukgeni.cm"));
				if(testSliver == null)
				{
					errorFound = true;
					addMessage(
						"Sliver not found",
						"Didn't find sliver on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else if(testSliver.manifest.document.length == 0)
				{
					errorFound = true;
					addMessage(
						"Sliver manifest not found",
						"Didn't find manifest on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				
				// Make sure the nodes are okay
				if(slice.nodes.length != 5)
				{
					errorFound = true;
					addMessage(
						"Incorrect number of nodes",
						"Found " + slice.aggregateSlivers.length + " node(s) instead of 5",
						LogMessage.LEVEL_FAIL
					);
				}
				testName = "exclusive-0";
				var testNode:VirtualNode = slice.nodes.getNodeByClientId(testName);
				if(testNode == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find node named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testNode.manifest.length == 0)
					{
						errorFound = true;
						addMessage(
							"Manifest not found for " + testName,
							"Didn't find manifest on " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.manager.hrn != "utahemulab.cm")
					{
						errorFound = true;
						addMessage(
							"Wrong manager for " + testName,
							"Node " + testName + " was found to be on " + testNode.manager.hrn,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.sliverType.selectedImage.id.full != "urn:publicid:IDN+emulab.net+image+emulab-ops//FEDORA10-STD")
					{
						errorFound = true;
						addMessage(
							"Wrong disk_image found found for " + testName,
							"Found wrong disk image: " + testNode.sliverType.selectedImage.id.full,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.Physical == null)
					{
						errorFound = true;
						addMessage(
							"No physical node found for " + testName,
							"No physical node found for " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					else if(testNode.Physical.hardwareTypes.getByName("pc3000") == null)
					{
						errorFound = true;
						addMessage(
							"Hardware_type mismatch found for " + testName,
							testName + " is not of type pc3000",
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.interfaces.length != 2)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interfaces on " + testName,
							testName + " has " + testNode.interfaces.length + " interfaces",
							LogMessage.LEVEL_FAIL
						);
					}
					var testSubName:String = "exclusive-0:if1";
					testInterface = testNode.interfaces.getByClientId(testSubName);
					if(testInterface == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					else if(testInterface.ip.address != "192.168.0.1")
					{
						errorFound = true;
						addMessage(
							"Didn't find correct IP address on " + testSubName,
							"Expecting to find 192.168.0.1, found " + testInterface.ip.address,
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-0:if0";
					testInterface = testNode.interfaces.getByClientId(testSubName);
					if(testInterface == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testNode.flackInfo.x != 192)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackX on " + testName,
							"Expected 192, found " + testNode.flackInfo.x,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.y != 51)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackY on " + testName,
							"Expected 51, found " + testNode.flackInfo.y,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.unbound == false)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackUnbound on " + testName,
							"Expected true, found false",
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				testName = "exclusive-1";
				testNode = slice.nodes.getNodeByClientId(testName);
				if(testNode == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find node named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testNode.manifest.length == 0)
					{
						errorFound = true;
						addMessage(
							"Manifest not found for " + testName,
							"Didn't find manifest on " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.manager.hrn != "ukgeni.cm")
					{
						errorFound = true;
						addMessage(
							"Wrong manager for " + testName,
							"Node " + testName + " was found to be on " + testNode.manager.hrn,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.Physical == null)
					{
						errorFound = true;
						addMessage(
							"No physical node found for " + testName,
							"No physical node found for " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.interfaces.length != 1)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interfaces on " + testName,
							testName + " has " + testNode.interfaces.length + " interfaces",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-1:if1";
					testInterface = testNode.interfaces.getByClientId(testSubName);
					if(testInterface == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					else if(testInterface.ip.address != "192.168.0.2")
					{
						errorFound = true;
						addMessage(
							"Didn't find correct IP address on " + testSubName,
							"Expecting to find 192.168.0.2, found " + testInterface.ip.address,
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testNode.flackInfo.x != 294)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackX on " + testName,
							"Expected 294, found " + testNode.flackInfo.x,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.y != 182)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackY on " + testName,
							"Expected 182, found " + testNode.flackInfo.y,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.unbound == false)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackUnbound on " + testName,
							"Expected true, found false",
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				// Newly added nodes
				testName = "test0";
				testNode = slice.nodes.getNodeByClientId(testName);
				if(testNode == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find node named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testNode.manifest.length == 0 )
					{
						errorFound = true;
						addMessage(
							"Manifest not found for " + testName,
							"Didn't find manifest on " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.manager.hrn != "utahemulab.cm")
					{
						errorFound = true;
						addMessage(
							"Wrong manager for " + testName,
							"Node " + testName + " was found to be on " + testNode.manager.hrn,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.Physical == null)
					{
						errorFound = true;
						addMessage(
							"No physical node found for " + testName,
							"No physical node found for " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.interfaces.length != 1)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interfaces on " + testName,
							testName + " has " + testNode.interfaces.length + " interfaces",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "test0:if0";
					testInterface = testNode.interfaces.getByClientId(testSubName);
					if(testInterface == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testNode.flackInfo.x != -1)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackX on " + testName,
							"Expected -1, found " + testNode.flackInfo.x,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.y != -1)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackY on " + testName,
							"Expected -1, found " + testNode.flackInfo.y,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.unbound == false)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackUnbound on " + testName,
							"Expected true, found false",
							LogMessage.LEVEL_FAIL
						);
					}
				}
				testName = "test1";
				testNode = slice.nodes.getNodeByClientId(testName);
				if(testNode == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find node named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testNode.manifest.length == 0)
					{
						errorFound = true;
						addMessage(
							"Manifest not found for " + testName,
							"Didn't find manifest on " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.manager.hrn != "utahemulab.cm")
					{
						errorFound = true;
						addMessage(
							"Wrong manager for " + testName,
							"Node " + testName + " was found to be on " + testNode.manager.hrn,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.Physical == null)
					{
						errorFound = true;
						addMessage(
							"No physical node found for " + testName,
							"No physical node found for " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.interfaces.length != 1)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interfaces on " + testName,
							testName + " has " + testNode.interfaces.length + " interfaces",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "test1:if0";
					testInterface = testNode.interfaces.getByClientId(testSubName);
					if(testInterface == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testNode.flackInfo.x != -1)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackX on " + testName,
							"Expected -1, found " + testNode.flackInfo.x,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.y != -1)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackY on " + testName,
							"Expected -1, found " + testNode.flackInfo.y,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.unbound == false)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackUnbound on " + testName,
							"Expected true, found false",
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				// Make sure the links are okay
				if(slice.links.length != 2)
				{
					errorFound = true;
					addMessage(
						"Incorrect links",
						"Found " + slice.aggregateSlivers.length + " links instead of 2",
						LogMessage.LEVEL_FAIL
					);
				}
				testName = "link-0";
				var testLink:VirtualLink = slice.links.getLinkByClientId(testName);
				if(testLink == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find link named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testLink.interfaceRefs.length != 2)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interface refs on " + testName,
							testName + " has " + testLink.interfaceRefs.length + " interface refs",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-0:if1";
					testInterfaceLeft = testLink.interfaceRefs.Interfaces.getByClientId(testSubName);
					if(testInterfaceLeft == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface ref " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-1:if1";
					testInterfaceRight = testLink.interfaceRefs.Interfaces.getByClientId(testSubName);
					if(testInterfaceRight == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface fref " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testLink.properties.length != 2)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of properties on " + testName,
							testName + " has " + testLink.properties.length + " properties",
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceRight, testInterfaceLeft);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceLeft.clientId,
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceLeft.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceLeft, testInterfaceRight);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceRight.clientId,
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceRight.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
				}
				testName = "lan";
				testLink = slice.links.getLinkByClientId(testName);
				if(testLink == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find link named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testLink.interfaceRefs.length != 3)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interface refs on " + testName,
							testName + " has " + testLink.interfaceRefs.length + " interface refs",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "exclusive-0:if0";
					testInterfaceLeft = testLink.interfaceRefs.Interfaces.getByClientId(testSubName);
					if(testInterfaceLeft == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface ref " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "test0:if0";
					testInterfaceRight = testLink.interfaceRefs.Interfaces.getByClientId(testSubName);
					if(testInterfaceRight == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface fref " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					testSubName = "test1:if0";
					var testInterfaceCenter:VirtualInterface = testLink.interfaceRefs.Interfaces.getByClientId(testSubName);
					if(testInterfaceRight == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find " + testSubName + " on " + testName,
							"Interface fref " + testSubName + " was not found",
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testLink.properties.length != 6)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of properties on " + testName,
							testName + " has " + testLink.properties.length + " properties",
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceRight, testInterfaceLeft);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceLeft.clientId,
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceLeft.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceLeft, testInterfaceRight);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceRight.clientId,
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceRight.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceCenter, testInterfaceLeft);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceCenter.clientId+" -> "+testInterfaceLeft.clientId,
							"Didn't find property for "+testInterfaceCenter.clientId+" -> "+testInterfaceLeft.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceCenter, testInterfaceRight);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceCenter.clientId+" -> "+testInterfaceRight.clientId,
							"Didn't find property for "+testInterfaceCenter.clientId+" -> "+testInterfaceRight.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceRight, testInterfaceCenter);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceCenter.clientId,
							"Didn't find property for "+testInterfaceRight.clientId+" -> "+testInterfaceCenter.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
					testProperty = testLink.properties.getFor(testInterfaceLeft, testInterfaceCenter);
					if(testProperty == null)
					{
						errorFound = true;
						addMessage(
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceCenter.clientId,
							"Didn't find property for "+testInterfaceLeft.clientId+" -> "+testInterfaceCenter.clientId,
							LogMessage.LEVEL_FAIL
						);
					}
				}
				
				// Problem after parsing the manifests...
				if(errorFound)
				{
					testFailed("Inconsistencies found in the allocated slice compared to the requested slice!");
					return;
				}
				
				testSucceeded();
				
				addMessage(
					"Preparing Step #" + NextStepNumber,
					"updating the slice"
				);
				
				// Save the previous request rspec for the slice into the history
				/*
				var generateHistoricRspec:GenerateRequestTask = new GenerateRequestTask(slice);
				generateHistoricRspec.start();
				if(generateHistoricRspec.Status == Task.STATUS_SUCCESS)
				{
					slice.history.states.push(CompressUtil.uncompress(generateHistoricRspec.requestRspec.document.removeNamespace(XmlUtil.historyNamespace).toXMLString()));
					addMessage(
						"Added history",
						generateHistoricRspec.requestRspec.document.toXMLString()
					);
				}
				else
				{
					addMessage(
						"Problem add history",
						"There was a problem generating the RSPEC to save into the slice's history",
						LogMessage.LEVEL_WARNING,
						false
					);
				}
				*/
				
				// Remove all but one node
				var removeNodes:VirtualNodeCollection = slice.nodes.getByManager(GeniMain.geniUniverse.managers.getByHrn("ukgeni.cm"));
				for each(var ukNode:VirtualNode in removeNodes.collection)
					ukNode.removeFromSlice();
				while(slice.nodes.length > 1)
					slice.nodes.collection[0].removeFromSlice();
				
				addMessage(
					"Slice details post-code-remove",
					slice.toString()
				);
				
				// Quick sanity check...
				if(slice.nodes.length != 1)
				{
					testFailed("Only one node should be left, but there are " + slice.nodes.length);
					return;
				}
				if(slice.nodes.collection[0].interfaces.length != 0)
				{
					testFailed("Node shouldn't have interfaces, but there are " + slice.nodes.collection[0].interfaces.length);
					return;
				}
				if(slice.links.length != 0)
				{
					testFailed("No links should be left, but there are " + slice.links.length);
					return;
				}
				
				addTest(
					"Submit slice",
					new SubmitSliceTaskGroup(slice, false), 
					firstSliceUpdatedToOneNode
				);
			}
		}
		
		// 10b. Check
		// 11a. Delete
		public function firstSliceUpdatedToOneNode(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != Success");
			else
			{
				addMessage(
					"Slice details post-remove-update",
					slice.toString()
				);
				
				// Check to make sure the slice parsed from the manifests mirrors what is expected
				var errorFound:Boolean = false;
				// Make sure the slivers are okay
				if(slice.aggregateSlivers.length != 1)
				{
					errorFound = true;
					addMessage(
						"Incorrect slivers",
						"Found " + slice.aggregateSlivers.length + " slivers instead of 1",
						LogMessage.LEVEL_FAIL
					);
				}
				
				var testName:String = "utahemulab.cm";
				var testSliver:AggregateSliver = slice.aggregateSlivers.getByManager(GeniMain.geniUniverse.managers.getByHrn(testName));
				if(testSliver == null)
				{
					errorFound = true;
					addMessage(
						"Sliver not found",
						"Didn't find sliver on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else if(testSliver.manifest.document.length == 0)
				{
					errorFound = true;
					addMessage(
						"Sliver manifest not found",
						"Didn't find manifest on " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				
				testName = "test0";
				var testNode:VirtualNode = slice.nodes.getNodeByClientId(testName);
				if(testNode == null)
				{
					errorFound = true;
					addMessage(
						testName + " not found",
						"Didn't find node named " + testName,
						LogMessage.LEVEL_FAIL
					);
				}
				else
				{
					if(testNode.manifest.length == 0)
					{
						errorFound = true;
						addMessage(
							"Manifest not found for " + testName,
							"Didn't find manifest on " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.manager.hrn != "utahemulab.cm")
					{
						errorFound = true;
						addMessage(
							"Wrong manager for " + testName,
							"Node " + testName + " was found to be on " + testNode.manager.hrn,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.Physical == null)
					{
						errorFound = true;
						addMessage(
							"No physical node found for " + testName,
							"No physical node found for " + testName,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.interfaces.length != 0)
					{
						errorFound = true;
						addMessage(
							"Incorrect number of interfaces on " + testName,
							testName + " has " + testNode.interfaces.length + " interfaces",
							LogMessage.LEVEL_FAIL
						);
					}
					
					if(testNode.flackInfo.x != -1)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackX on " + testName,
							"Expected -1, found " + testNode.flackInfo.x,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.y != -1)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackY on " + testName,
							"Expected -1, found " + testNode.flackInfo.y,
							LogMessage.LEVEL_FAIL
						);
					}
					if(testNode.flackInfo.unbound == false)
					{
						errorFound = true;
						addMessage(
							"Found incorrect FlackUnbound on " + testName,
							"Expected true, found false",
							LogMessage.LEVEL_FAIL
						);
					}
				}
				if(slice.links.length != 0)
				{
					errorFound = true;
					addMessage(
						"Found " + slice.links.length + " link(s) when there shouldn't be any.",
						"Found " + slice.links.length + " link(s) when there shouldn't be any.",
						LogMessage.LEVEL_FAIL
					);
				}
				
				// Problem after parsing the manifests...
				if(errorFound)
				{
					testFailed("Inconsistencies found in the allocated slice compared to the requested slice!");
					return;
				}
				
				testSucceeded();
				
				// Remove the resources to call delete on all created slivers
				slice.removeComponents();
				
				addTest(
					"Submit slice",
					new SubmitSliceTaskGroup(slice, false), 
					firstSliceDeleted
				);
			}
		}
		
		// 11b. Check
		public function firstSliceDeleted(event:TaskEvent):void
		{
			var slice:Slice = (event.task as SubmitSliceTaskGroup).slice;
			
			if(event.task.Status != Task.STATUS_SUCCESS)
				testFailed("Status != SUCCESS");
			else
			{
				addMessage(
					"Slice details post-delete",
					slice.toString()
				);
				
				// Sanity check...
				var errorFound:Boolean = false;
				if(slice.aggregateSlivers.length != 0)
				{
					errorFound = true;
					addMessage(
						"Found " + slice.aggregateSlivers.length + " sliver(s) when there shouldn't be any.",
						"Found " + slice.aggregateSlivers.length + " sliver(s) when there shouldn't be any.",
						LogMessage.LEVEL_FAIL
					);
				}
				if(slice.nodes.length != 0)
				{
					errorFound = true;
					addMessage(
						"Found " + slice.nodes.length + " nodes(s) when there shouldn't be any.",
						"Found " + slice.nodes.length + " nodes(s) when there shouldn't be any.",
						LogMessage.LEVEL_FAIL
					);
				}
				if(slice.links.length != 0)
				{
					errorFound = true;
					addMessage(
						"Found " + slice.links.length + " links(s) when there shouldn't be any.",
						"Found " + slice.links.length + " links(s) when there shouldn't be any.",
						LogMessage.LEVEL_FAIL
					);
				}
				
				// Problem after parsing the manifests...
				if(errorFound)
				{
					testFailed("Inconsistencies found in the allocated slice compared to the requested slice!");
					return;
				}
				
				testsSucceeded();
			}
		}
	}
}