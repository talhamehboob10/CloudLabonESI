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
	import com.flack.geni.plugins.SliverTypeInterface;
	import com.flack.geni.resources.DiskImageCollection;

	/**
	 * Describes the sliver environment which will be given to the user
	 * 
	 * @author mstrum
	 * 
	 */
	public class SliverType
	{
		[Bindable]
		public var name:String;
		public var extensions:Extensions = new Extensions();
		
		// Advertised
		// Standard
		public var diskImages:DiskImageCollection = new DiskImageCollection();
		
		// Requestables
		// Standard
		[Bindable]
		public var selectedImage:DiskImage = null;
		
		public var sliverTypeSpecific:SliverTypeInterface = null;
		
		/**
		 * 
		 * @param newName Name of the sliver type
		 * 
		 */
		public function SliverType(newName:String = "")
		{
			name = newName;
			var topLevelInterface:SliverTypeInterface = SliverTypes.getSliverTypeInterface(newName);
			if(topLevelInterface != null)
				sliverTypeSpecific = topLevelInterface.Clone;
		}
		
		public function get Clone():SliverType
		{
			var newSliverType:SliverType = new SliverType(name);
			if(selectedImage != null)
				newSliverType.selectedImage = new DiskImage(
					selectedImage.id.full,
					selectedImage.os,
					selectedImage.version,
					selectedImage.description,
					selectedImage.isDefault
				);
			newSliverType.diskImages = diskImages;
			if(sliverTypeSpecific != null)
				newSliverType.sliverTypeSpecific = sliverTypeSpecific.Clone;
			newSliverType.extensions = extensions.Clone;
			return newSliverType;
		}
		
		public function toString():String
		{
			var result:String = "[SliverType Name="+name+"]\n";
			if(diskImages.length > 0)
			{
				result += "\t[DiskImages]\n";
				for each(var diskImage:DiskImage in diskImages.collection)
					result += "\t\t" + diskImage.toString() + "\n";
				result += "\t[/DiskImages]\n";
			}
			
			return result += "[/SliverType]\n";
		}
	}
}