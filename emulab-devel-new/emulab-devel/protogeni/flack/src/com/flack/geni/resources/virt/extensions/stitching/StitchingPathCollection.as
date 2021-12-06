package com.flack.geni.resources.virt.extensions.stitching
{
	import com.flack.geni.resources.virt.VirtualLink;

	public final class StitchingPathCollection
	{
		public var collection:Vector.<StitchingPath>;
		public function StitchingPathCollection()
		{
			collection = new Vector.<StitchingPath>();
		}
		
		public function add(s:StitchingPath):void
		{
			collection.push(s);
		}
		
		public function remove(s:StitchingPath):void
		{
			var idx:int = collection.indexOf(s);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(s:StitchingPath):Boolean
		{
			return collection.indexOf(s) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function getByVirtualLink(link:VirtualLink):StitchingPath
		{
			for each(var path:StitchingPath in collection)
			{
				if(path.link == link) {
					return path;
				}
			}
			return null;
		}
		
		public function getByVirtualLinkClientId(clientId:String):StitchingPath
		{
			for each(var path:StitchingPath in collection)
			{
				if(path.link.clientId == clientId) {
					return path;
				}
			}
			return null;
		}
	}
}