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

package com.flack.geni.plugins.instools.instasks
{
	import com.flack.geni.plugins.instools.Instools;
	import com.flack.geni.plugins.instools.SliceInstoolsDetails;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.tasks.process.GenerateRequestManifestTask;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.cm.StartSliverCmTask;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.MathUtil;
	
	import mx.controls.Alert;
	
	public final class SaveManifestTask extends ProtogeniXmlrpcTask
	{
		public var sliver:AggregateSliver;
		public var details:SliceInstoolsDetails;
		public var manifest:Rspec;
		
		public function SaveManifestTask(newSliver:AggregateSliver, useDetails:SliceInstoolsDetails, newManifest:Rspec)
		{
			super(
				newSliver.manager.url,
				Instools.instoolsModule + "/" + useDetails.apiVersion.toFixed(1),
				Instools.saveManifest,
				"Save Manifest @ " + newSliver.manager.hrn,
				"Saving manifest on " + newSliver.manager.hrn + " on slice named " + newSliver.slice.Name,
				"Save Manifest"
			);
			relatedTo.push(newSliver);
			relatedTo.push(newSliver.manager);
			relatedTo.push(newSliver.slice);
			sliver = newSliver;
			details = useDetails;
			manifest = newManifest;
		}
		
		override protected function createFields():void
		{
			addNamedField("urn", sliver.slice.id.full);
			addNamedField("INSTOOLS_VERSION", details.useStableINSTOOLS ? Instools.stable_version[sliver.manager.id.full] : Instools.devel_version[sliver.manager.id.full]);
			//addNamedField("INSTOOLS_VERSION",Instools.devel_version[sliver.manager.id.full]);
			addNamedField("credentials", [sliver.slice.credential.Raw]);
			addNamedField("manifest",manifest.document);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code ==  ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				addMessage(
					"Manifest Saved",
					"Saved manifest on " + sliver.manager.hrn,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				super.afterComplete(addCompletedMessage);
				return;
			}
			else
				faultOnSuccess();
		}
		
		override protected function afterError(taskError:TaskError):void
		{
			failed();
			super.afterError(taskError);
		}
		
		override protected function runCancel():void
		{
			failed();
		}
		
		public function failed():void
		{
			addMessage(
				"Poll INSTOOLS status failed",
				"Poll INSTOOLS status failed",
				LogMessage.LEVEL_FAIL,
				LogMessage.IMPORTANCE_HIGH
			);
			Alert.show(
				"Failed to poll INSTOOLS status on " + sliver.manager.hrn + ". ",
				"Problem polling INSTOOLS status"
			);
		}
	}
}