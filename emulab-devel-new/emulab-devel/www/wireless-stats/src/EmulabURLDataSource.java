/*
 * Copyright (c) 2006-2007 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 */

import java.util.*;
import java.net.URL;

public class EmulabURLDataSource implements DataSource {
    
    // String uid = this.getParameter("uid");
    // String auth = this.getParameter("auth");
    // String mapurl = this.getParameter("mapurl");
    // String dataurl = this.getParameter("dataurl");
    // String positurl = this.getParameter("positurl");
    // String datasetStr = this.getParameter("datasets");
    
    
    private URL base;
    private String stdargs;
    private String srcarg;
    private String maparg;
    private String dataarg;
    private String positarg;
    
    Vector dsListeners;
    
    public EmulabURLDataSource(DataCache cache,URL codebase,String stdargs) {
        this.base = codebase;
        this.stdargs = stdargs;
        
        this.dsListeners = new Vector();
    }
    
    public void refreshSources() {
        
    }
    
    public String[] getSources() {
        return null;
    }

    public String[] getSourceSetList(String src) {
        return null;
    }

    public Dataset fetchData(String Source,String set) {
        return null;
    }
    
    public void addDataSourceListener(DataSourceListener dsl) {
        if (!dsListeners.contains(dsl)) {
            dsListeners.add(dsl);
        }
    }
    
    public void removeDataSourceListener(DataSourceListener dsl) {
        if (dsListeners.contains(dsl)) {
            dsListeners.remove(dsl);
        }
    }
    
    void notifyDataSourceListeners() {
        
    }
    
}
