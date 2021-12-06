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

package com.flack.emulab.resources.physical
{
	import com.flack.emulab.resources.NamedObject;

	/**
	 * Disk image used for a resource
	 * 
	 * @author mstrum
	 * 
	 */
	public class Osid extends NamedObject
	{
		public var os:String;
		public var description:String;
		public var pid:String;
		public var version:String;
		public var creator:String;
		public var created:Date;
		// new?
		public var osfeatures:Vector.<String> = new Vector.<String>();
		//public var fullosid:String;
		//public var shared:Boolean;
		
		public function Osid(newName:String = "",
								  newOs:String = "",
								  newVersion:String = "",
								  newDescription:String = "",
								  newPid:String = "",
								  newCreator:String = "",
								  newCreated:Date = null)
		{
			super(newName);
			os = newOs;
			version = newVersion;
			description = newDescription;
			pid = newPid;
			creator = newCreator;
			created = newCreated;
		}
	}
}