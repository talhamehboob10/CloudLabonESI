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

public class DatasetModel {
    
    final static int TYPE_NEW = 1;
    final static int TYPE_UNLOAD = 2;
    final static int TYPE_CUR_CHANGE = 3;
    
    private Hashtable datasetModels;
    private Dataset currentDataset;
    private String currentDatasetName;
    private MapDataModel currentModel;
    private Vector listeners;
    
    public DatasetModel() {
        this.datasetModels = new Hashtable();
        this.currentModel = null;
        this.currentDataset = null;
        this.listeners = new Vector();
    }
    
    public void setCurrentModel(String dsn) {
        Dataset d = (Dataset)datasetModels.get(dsn);
        MapDataModel mdm = d.model;
        if (mdm != null && mdm != currentModel) {
            this.currentModel = mdm;
            this.currentDataset = d;
            this.currentDatasetName = dsn;
            notifyModelListeners(TYPE_CUR_CHANGE,dsn);
        }
    }
    
    public MapDataModel getCurrentModel() {
        if (this.currentDataset == null) {
            // scan through our list and take the first one we find.
            for (Enumeration e1 = datasetModels.elements(); e1.hasMoreElements(); ) {
                this.currentDataset = (Dataset)e1.nextElement();
                this.currentModel = this.currentDataset.model;
                this.currentDatasetName = this.currentDataset.name;
            }
        }
        return this.currentModel;
    }
    
    public String getCurrentDatasetName() {
        return this.currentDatasetName;
    }
    
    public Dataset getCurrentDataset() {
        if (this.currentDataset == null) {
            // scan through our list and take the first one we find.
            for (Enumeration e1 = datasetModels.elements(); e1.hasMoreElements(); ) {
                this.currentDataset = (Dataset)e1.nextElement();
                this.currentModel = this.currentDataset.model;
                this.currentDatasetName = this.currentDataset.name;
            }
        }
        return this.currentDataset;
    }
    
    public void addDataset(String dsn,Dataset d) {
        datasetModels.put(dsn,d);
        notifyModelListeners(TYPE_NEW,dsn);
    }
    
    public void removeDataset(String dsn) {
        datasetModels.remove(dsn);
        notifyModelListeners(TYPE_UNLOAD,dsn);
    }
    
    public Dataset getDataset(String name) {
        return (Dataset)this.datasetModels.get(name);
    }
    
    public Vector getDatasetNames() {
        Vector retval = new Vector();
        for (Enumeration e1 = this.datasetModels.keys(); e1.hasMoreElements(); ) {
            retval.add(e1.nextElement());
        }
        return retval;
    }
    
    public Vector getDatasets() {
        Vector retval = new Vector();
        for (Enumeration e1 = this.datasetModels.elements(); e1.hasMoreElements(); ) {
            retval.add(e1.nextElement());
        }
        return retval;
    }
    
    public void addDatasetModelListener(DatasetModelListener dl) {
        if (!this.listeners.contains(dl)) {
            this.listeners.add(dl);
        }
    }
    
    public void removeDatasetModelListener(DatasetModelListener dl) {
        if (this.listeners.contains(dl)) {
            this.listeners.remove(dl);
        }
    }
    
    void notifyModelListeners(int type,String ds) {
        for (Enumeration e1 = listeners.elements(); e1.hasMoreElements(); ) {
            DatasetModelListener dl = (DatasetModelListener)e1.nextElement();
            switch (type) {
                case TYPE_NEW:
                    dl.newDataset(ds,this);
                    break;
                case TYPE_UNLOAD:
                    dl.datasetUnloaded(ds,this);
                    break;
                case TYPE_CUR_CHANGE:
                    dl.currentDatasetChanged(ds,this);
                    break;
                default:
                    break;
            }
        }
    }
    
    
}
