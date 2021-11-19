package com.flack.geni.resources.virt.extensions.stitching
{
	import com.flack.geni.resources.virt.VirtualLink;

	public class StitchingPath
	{
		public var link:VirtualLink;
		public var hops:StitchingHopCollection;
		
		public function StitchingPath(newLink:VirtualLink=null, newHops:StitchingHopCollection=null)
		{
			link = newLink;
			if (newHops != null) {
				hops = newHops;
			} else {
				hops = new StitchingHopCollection();
			}
		}
	}
}