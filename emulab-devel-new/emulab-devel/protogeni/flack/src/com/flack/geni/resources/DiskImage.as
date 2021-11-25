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

package com.flack.geni.resources
{
	import com.flack.shared.resources.IdentifiableObject;
	import com.flack.shared.resources.IdnUrn;

	/**
	 * Disk image used for a resource
	 * 
	 * @author mstrum
	 * 
	 */
	public class DiskImage extends IdentifiableObject
	{
		/**
		 * 
		 * @param newId Full IDN-URN string
		 * @param newOs OS description
		 * @param newVersion Version description
		 * @param newDescription General description
		 * @param newIsDefault Is this the default image?
		 * 
		 */
		public function DiskImage(newId:String = "",
								  newOs:String = "",
								  newVersion:String = "",
								  newDescription:String = "",
								  newIsDefault:Boolean = false,
								  newUrl:String = "",
								  newCreator:String = "")
		{
			super(newId);
			/*if(id.full.length > 0 && IdnUrn.isIdnUrn(newId))
				id = IdnUrn.makeFrom(id.authority, id.type, id.name.replace(":", "//"));*/
			os = newOs;
			version = newVersion;
			description = newDescription;
			isDefault = newIsDefault;
			url = newUrl;
			creator = newCreator;
		}
		
		public var os:String;
		public var version:String;
		public var description:String;
		public var url:String;
		public var creator:String
		public var isDefault:Boolean;
		
		public var extensions:Extensions = new Extensions();
		
		public function get ShortId():String
		{
			if(id == null)
				return "";
			if(!IdnUrn.isIdnUrn(id.full))
				return id.full;
			return id.name;
		}
		
		/**
		 * In an image like 'emulab-ops//FC6-STD', the OSID would be FC6-STD
		 * @return 
		 * 
		 */
		public function get Osid():String
		{
			var shortId:String = ShortId;
			var idx:int = shortId.indexOf("//");
			if(idx > 0)
				return shortId.substring(idx+2);
			idx = shortId.indexOf(":");
			if(idx > 0)
				return shortId.substring(idx+1);
			return shortId;
		}
		
		/**
		 * In an image like 'emulab-ops//FC6-STD', the domain would be emulab-ops
		 * 
		 * @return 
		 * 
		 */
		public function get Domain():String
		{
			var shortId:String = ShortId;
			var idx:int = shortId.indexOf("//");
			if(idx > 0)
				return shortId.substring(idx+1);
			idx = shortId.indexOf(":");
			if(idx > 0)
				return shortId.substring(idx);
			return shortId;
		}
		
		override public function toString():String
		{
			return "[DiskImage ID="+id.full+"]";
		}
	}
}