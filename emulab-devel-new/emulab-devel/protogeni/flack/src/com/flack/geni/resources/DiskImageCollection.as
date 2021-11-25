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
	import com.flack.shared.resources.IdnUrn;

	/**
	 * Collection of extension spaces
	 * 
	 * @author mstrum
	 * 
	 */
	public class DiskImageCollection
	{
		public var collection:Vector.<DiskImage> = new Vector.<DiskImage>();
		public function DiskImageCollection()
		{
			collection = new Vector.<DiskImage>();
		}
		
		public function add(image:DiskImage):void
		{
			collection.push(image);
		}
		
		public function remove(image:DiskImage):void
		{
			var idx:int = collection.indexOf(image);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function removeAll(imgs:DiskImageCollection):void
		{
			for each(var img:DiskImage in imgs.collection)
				remove(img);
		}
		
		public function contains(image:DiskImage):Boolean
		{
			return collection.indexOf(image) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get Creators():Vector.<String>
		{
			var creators:Vector.<String> = new Vector.<String>();
			for each(var image:DiskImage in collection)
			{
				if(creators.indexOf(image.creator) == -1)
					creators.push(image.creator);
			}
			return creators;
		}
		
		/**
		 * 
		 * @param shortId Short ID (e.g. emulab-ops//FC6-STD)
		 * @return Disk image with the same short ID
		 * 
		 */
		public function getByShortId(shortId:String):DiskImage
		{
			for each(var image:DiskImage in collection)
			{
				if(image.ShortId == shortId)
					return image;
			}
			return null;
		}
		
		/**
		 * 
		 * @param id Full IDN-URN
		 * @return Disk image matching the ID
		 * 
		 */
		public function getByLongId(id:String):DiskImage
		{
			for each(var image:DiskImage in collection)
			{
				if(image.id.full == id)
					return image;
			}
			return null;
		}
		
		public function getByCreator(urn:String):DiskImageCollection
		{
			var result:DiskImageCollection = new DiskImageCollection();
			for each(var image:DiskImage in collection)
			{
				if(image.creator == urn)
					result.add(image);
			}
			return result;
		}
		
		public function getByAuthority(authority:String):DiskImageCollection
		{
			var result:DiskImageCollection = new DiskImageCollection();
			for each(var image:DiskImage in collection)
			{
				if(IdnUrn.isIdnUrn(image.id.full) && image.id.authority == authority)
					result.add(image);
			}
			return result;
		}
		
		/**
		 * 
		 * @return Default image
		 * 
		 */
		public function getDefault(creatorUrn:String = ""):DiskImage
		{
			for each(var image:DiskImage in collection)
			{
				if(creatorUrn.length == 0 || image.creator == creatorUrn)
				{
					if(image.isDefault)
						return image;
				}
			}
			return null;
		}
	}
}