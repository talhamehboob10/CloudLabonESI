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

package com.flack.shared.utils
{
	import flash.utils.ByteArray;
	
	import mx.utils.Base64Decoder;
	import mx.utils.Base64Encoder;

	public class CompressUtil
	{
		public static function uncompress(base64Compressed:String):String
		{
			var decodor:Base64Decoder = new Base64Decoder();
			decodor.decode(base64Compressed);
			var bytes:ByteArray = decodor.toByteArray();
			bytes.uncompress();
			return bytes.toString();
		}
		
		// XXX needs to work...
		public static function compress(original:String):String
		{
			var bytes:ByteArray = new ByteArray();
			bytes.writeUTFBytes(original);
			bytes.compress();
			var encoder:Base64Encoder = new Base64Encoder();
			encoder.encodeBytes(bytes, 0, bytes.length);
			return encoder.toString();
		}
	}
}