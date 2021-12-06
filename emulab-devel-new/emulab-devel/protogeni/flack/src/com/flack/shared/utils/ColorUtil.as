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
	/**
	 * Predefined colors available for use.  Using one index into the colors
	 * basically give you three shades of the same color. It should be noted
	 * that in order to increase the number of colors they have been duplicated
	 * so that darks are also in lights and lights in darks so that you can
	 * have a dark on light and light and dark as two different schemes.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ColorUtil
	{
		public static const validDark:uint = 0x006600;
		public static const validLight:uint = 0x27C427;
		public static const invalidDark:uint = 0x990000;
		public static const invalidLight:uint = 0xF08080;
		public static const changingDark:uint = 0xCC6600;
		public static const changingLight:uint = 0xFFCC00;
		public static const unknownDark:uint = 0x2F4F4F;
		public static const unknownLight:uint = 0xEAEAEA;
		
		/*
		
		Back		Color
		0xE7E7E7		0x644680
		0xB6CFF5		0x4D34A0
		0x98D7E4		0x423B7E
		0xE3D7FF		0x7A18B5
		0xFBD3E0		0x711974
		0xF2B2A8		0xAE1C47
		
		0xC2C2C2		0xFFFFFF
		0x4986E7		0xFFFFFF
		0x2DA2BB		0xFFFFFF
		0xB99AFF		0xFFFFFF
		0xF691B2		0x994A80
		0xFB4C2F		0xFFFFFF
		
		0xFFC8AF		0x7A2E0B
		0xFFDEB5		0x7A4706
		0xFBE983		0x594C36
		0xFDEDC1		0x684E50
		0xB3EFD3		0x0B4E6B
		0xA2DCC1		0x435064
		
		0xFF7537		0xFFFFFF
		0xFFAD46		0xFFFFFF
		0xEBDBDE		0x662E37
		0xCCA6AC		0xFFFFFF
		0x42D692		0x1F424E
		0x16A765		0xFFFFFF
		
		*/
		public static var colorUsage:Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		public static const colorsLight:Array =
			new Array(
				// light
				0xCCCCCC,	// grey
				0xF2AEAC,	// red
				0xD8E4AA,	// green
				0xB8D2EB,	// blue
				0xF2D1B0,	// orange
				0xD4B2D3,	// dark purple
				0xDDB8A9,	// dark red
				0xEBBFD9,	// light purple
				0x594C36, //0xFBE983, //0xFFFCCF,	// NEW yellow
				0x49E9BD,	// NEW green
				0xFFD39B,	// NEW brown
				// dark
				0x010101,	// grey
				0xED2D2E,	// red
				0x008C47,	// green
				0x1859A9,	// blue
				0xF37D22,	// orange
				0x662C91,	// dark purple
				0xA11D20,	// dark red
				0xB33893,	// light purple
				0xFBE983, //0x594C36, //0xCDAD00,	// NEW yellow
				0x388E8E,	// NEW green
				0x5C4033	// NEW brown
			);
		public static const colorsMedium:Array =
			new Array(
				0x727272,	// grey
				0xF1595F,	// red
				0x79C36A,	// green
				0x599AD3,	// blue
				0xF9A65A,	// orange
				0x9E66AB,	// dark purple
				0xCD7058,	// dark red
				0xD77FB3,	// light purple
				0x594C36, //0xFBE983, //0xFFEC8B,	// NEW yellow
				0x45C3B8,	// NEW green
				0xAA6600,	// NEW brown
				0x727272,	// grey
				0xF1595F,	// red
				0x79C36A,	// green
				0x599AD3,	// blue
				0xF9A65A,	// orange
				0x9E66AB,	// dark purple
				0xCD7058,	// dark red
				0xD77FB3,	// light purple
				0x594C36, //0xFBE983, //0xFFEC8B,	// NEW yellow
				0x45C3B8,	// NEW green
				0xAA6600	// NEW brown
			);
		
		public static const colorsDark:Array =
			new Array(
				0x010101,	// grey
				0xED2D2E,	// red
				0x008C47,	// green
				0x1859A9,	// blue
				0xF37D22,	// orange
				0x662C91,	// dark purple
				0xA11D20,	// dark red
				0xB33893,	// light purple
				0xFBE983, //0x594C36, //0xCDAD00,	// NEW yellow
				0x388E8E,	// NEW green
				0x5C4033,	// NEW brown
				// light
				0xCCCCCC,	// grey
				0xF2AEAC,	// red
				0xD8E4AA,	// green
				0xB8D2EB,	// blue
				0xF2D1B0,	// orange
				0xD4B2D3,	// dark purple
				0xDDB8A9,	// dark red
				0xEBBFD9,	// light purple
				0x594C36, //0xFBE983, //0xFFFCCF,	// NEW yellow
				0x49E9BD,	// NEW green
				0xFFD39B	// NEW brown
			);
		
		
		public static function getNextColorIdx():int
		{
			var lowestUsageIdx:int = 0;
			for(var i:int = 1; i < colorsMedium.length; i++)
			{
				if(ColorUtil.colorUsage[i] < ColorUtil.colorUsage[lowestUsageIdx])
					lowestUsageIdx = i;
			}
			return useColorIdx(lowestUsageIdx);
		}
		
		public static function useColorIdx(idx:int):int
		{
			colorUsage[idx]++;
			return idx;
		}
		
		public static function getColorIdxFor(name:String):int
		{
			var idx:int = 0;
			switch(name)
			{
				case "emulab.net":
					return useColorIdx(0);
				case "schooner.wail.wisc.edu":
					return useColorIdx(1);
				case "cmcl.cs.cmu.edu":
					return useColorIdx(2);
				case "jonlab.tbres.emulab.net":
					return useColorIdx(3);
				case "myelab.testbed.emulab.net":
					return useColorIdx(4);
				case "pgeni.gpolab.bbn.com":
					return useColorIdx(5);
				case "cis.fiu.edu":
					return useColorIdx(6);
				case "pgeni3.gpolab.bbn.com":
					return useColorIdx(7);
				case "shadownet.uky.emulab.net":
					return useColorIdx(8);
				case "pgeni1.gpolab.bbn.com":
					return useColorIdx(9);
				case "example.org":
					return useColorIdx(10);
				case "plc":
					return useColorIdx(11);
				case "geelab.geni.emulab.net":
					return useColorIdx(12);
				case "etri-cm1.kreonet.net":
					return useColorIdx(13);
				case "uky.emulab.net":
					return useColorIdx(14);
				default:
					return getNextColorIdx();
			}
		}
	}
}