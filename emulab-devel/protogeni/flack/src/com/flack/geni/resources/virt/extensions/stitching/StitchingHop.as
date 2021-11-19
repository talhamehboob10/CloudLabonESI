package com.flack.geni.resources.virt.extensions.stitching
{

	public class StitchingHop
	{
		public var id:Number;
		public var requestLink:StitchingLink;
		public var advertisedLink:StitchingLink;
		public var nextHop:Number;
		
		public function StitchingHop(newId:Number=NaN, newRequestLink:StitchingLink=null, newAdvertisedLink:StitchingLink=null, newNextHop:Number=NaN)
		{
			id = newId;
			requestLink = newRequestLink;
			advertisedLink = newAdvertisedLink;
			nextHop = newNextHop;
		}
	}
}