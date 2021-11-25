package com.flack.geni.resources.virt.extensions.stitching
{
	import com.flack.geni.resources.sites.GeniManager;

	public class StitchingDependency
	{
		public var hop:StitchingHop;
		public var aggregate:GeniManager;
		public var dependencies:StitchingDependencyCollection;
		public var importVlans:Boolean;
		
		public function StitchingDependency(newHop:StitchingHop=null, newAggregate:GeniManager=null, newDependencies:StitchingDependencyCollection=null, newImportVlans:Boolean=false)
		{
			hop = newHop;
			aggregate = newAggregate;
			importVlans = newImportVlans;
			if(newDependencies == null) {
				dependencies = new StitchingDependencyCollection();
			} else {
				dependencies = newDependencies;
			}
		}
	}
}