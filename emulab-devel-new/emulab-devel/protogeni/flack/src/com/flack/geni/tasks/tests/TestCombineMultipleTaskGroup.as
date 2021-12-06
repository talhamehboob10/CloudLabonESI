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
	import com.flack.geni.plugins.instools.Instools;
	import com.flack.geni.plugins.instools.instasks.InstrumentizeSliceGroupTask;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.tasks.groups.slice.CreateSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.ImportSliceTaskGroup;
	import com.flack.geni.tasks.groups.slice.SubmitSliceTaskGroup;
	import com.flack.geni.tasks.process.GenerateRequestManifestTask;
	import com.flack.geni.tasks.process.ParseRequestManifestTask;
	import com.flack.shared.SharedMain;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskEvent;
	import com.flack.shared.tasks.http.HttpTask;
	
	/**
	 * Runs a series of tests to see if the code for working with slices is correct
	 * 
	 * @author mstrum
	 * 
	 */
	public final class TestCombineMultipleTaskGroup extends TestTaskGroup
	{
		public function TestCombineMultipleTaskGroup()
		{
			super(
				"Test multiple",
				"Test multiple"
			);
		}
		
		override protected function startTest():void
		{
			var blankSlice:Slice = new Slice();
			(new ParseRequestManifestTask(new AggregateSliver(blankSlice, GeniMain.geniUniverse.managers.getByHrn("utahemulab.cm")) , new Rspec((new TestsliceRspecRight()).toString()), true)).start();
			(new ParseRequestManifestTask(new AggregateSliver(blankSlice, GeniMain.geniUniverse.managers.getByHrn("ukgeni.cm")) , new Rspec((new TestsliceRspecLeft()).toString()), true)).start();
			
			var generate:GenerateRequestManifestTask = new GenerateRequestManifestTask(blankSlice.aggregateSlivers.collection[0], true, false, false);
			generate.start();
			
			var test:String = generate.resultRspec.document;
		}
	}
}