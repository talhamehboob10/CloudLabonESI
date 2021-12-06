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

package com.flack.geni.plugins.gemini
{
	import com.flack.geni.resources.DiskImage;
	import com.flack.shared.tasks.http.HttpTask;
	
	/**
	 * Downloads a public list of ProtoGENI slice authorities
	 * 
	 * @author mstrum
	 * 
	 */
	public class GetDiskImagesTask extends HttpTask
	{
		public function GetDiskImagesTask()
		{
			super(
				"http://gemini.netlab.uky.edu/DiskImages.json",
				"Download GEMINI Disk Image Descriptors",
				"Gets the latest GEMINI disk images for instrumentizing slices"
			);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			var result:Object = JSON.parse(data);
			
			Gemini.globalImage = new DiskImage(result.GN_Image_URN);
			Gemini.globalImage.url = result.GN_Image_URI;
			Gemini.localImage = new DiskImage(result.MP_Image_URN);
			Gemini.localImage.url = result.MP_Image_URI;
			
			Gemini.prepared = true;
			
			super.afterComplete(addCompletedMessage);
		}
	}
}