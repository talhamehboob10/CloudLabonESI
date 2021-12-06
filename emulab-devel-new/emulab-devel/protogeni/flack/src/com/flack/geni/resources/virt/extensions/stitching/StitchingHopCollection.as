package com.flack.geni.resources.virt.extensions.stitching
{
	public final class StitchingHopCollection
	{
		public var collection:Vector.<StitchingHop>;
		public function StitchingHopCollection()
		{
			collection = new Vector.<StitchingHop>();
		}
		
		public function add(s:StitchingHop):void
		{
			collection.push(s);
		}
		
		public function remove(s:StitchingHop):void
		{
			var idx:int = collection.indexOf(s);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(s:StitchingHop):Boolean
		{
			return collection.indexOf(s) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function getById(id:Number):StitchingHop
		{
			for each(var hop:StitchingHop in collection)
			{
				if(hop.id == id) {
					return hop;
				}
			}
			return null;
		}
		
		public function getByLinkId(id:String):StitchingHop
		{
			for each(var hop:StitchingHop in collection)
			{
				if(hop.requestLink.id.full == id) {
					return hop;
				}
			}
			return null;
		}
	}
}