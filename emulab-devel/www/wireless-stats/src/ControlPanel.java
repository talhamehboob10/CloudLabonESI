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
import java.awt.Image;
import javax.swing.*;
import javax.swing.event.*;
import java.awt.*;
import java.awt.event.*;
import java.beans.*;

public class ControlPanel extends javax.swing.JPanel 
    implements ChangeListener,DatasetModelListener {
    
    private String currentModelName;
    private MapDataModel currentModel;
    private Vector modelNames;
    // a map of model name to a Vector (containing JComponents -- generally
    // (label,jcombobox) pairs... all of which get added to the indexPanel
    // when their model is swapped in.
    private Hashtable modelIndexComponents;
    // placements for components in above table
    private Hashtable modelIndexPlacements;
    // make our own comboboxmodel so that we can add model names ex post facto
    private DefaultComboBoxModel dDCM;
    
    private DatasetModel dmodel;
    
    // ummm, a gentler comment: this is needed to preserve the component's
    // identity as a bean... so I can add it to the appropriate DND panel
    // in netbeans.
    public ControlPanel() {
        super();
    }
    
    public ControlPanel(DatasetModel dm) {
        super();
        
        this.dmodel = dm;
        this.modelNames = new Vector();
        this.currentModelName = null;
        this.currentModel = null;
        
        this.modelIndexComponents = new Hashtable();
        this.modelIndexPlacements = new Hashtable();
        
        String tmpModelName = null;
        MapDataModel tmpModel = null;
        
        for (Enumeration e1 = dmodel.getDatasetNames().elements(); e1.hasMoreElements(); ) {
            String modelName = (String)e1.nextElement();
            Dataset ds = (Dataset)dmodel.getDataset(modelName);
            
            modelNames.add(modelName);
            if (tmpModelName == null) {
                tmpModelName = modelName;
                tmpModel = ds.model;
            }
            System.err.println("considered model '"+modelName+"'");
        }
        
        dDCM = new DefaultComboBoxModel(this.modelNames);
        
        initComponents();
        
        if (this.dmodel.getCurrentModel() != null) {
            this.currentModelName = this.dmodel.getCurrentDatasetName();
            this.currentModel = this.dmodel.getCurrentModel();
            System.err.println("setting init model to '"+this.currentModelName+"' with model="+this.currentModel);
            setModel(this.currentModelName,this.currentModel);
        }
        else {
            System.err.println("defaulting init model to '"+tmpModelName+"' with model="+tmpModel);
            setModel(tmpModelName,tmpModel);
        }
        
        this.dmodel.addDatasetModelListener(this);
        
    }
    
    public void newDataset(String dsn,DatasetModel model) {
        if (!this.modelNames.contains(dsn)) {
            this.modelNames.add(dsn);
            this.dDCM.addElement(dsn);
        }
    }
    
    public void datasetUnloaded(String dsn,DatasetModel model) {
        if (this.modelNames.contains(dsn)) {
            this.modelNames.remove(dsn);
            this.dDCM.removeElement(dsn);
        }
    }
    
    public void currentDatasetChanged(String dsn,DatasetModel model) {
        // XXX: this cannot happen to us at the moment... but if it does...
        this.setModel(dsn,model.getCurrentModel());
    }
    
    private void setSelectedNodes(Vector nodes) {
        // check to see if the current selection is the same as what
        // we have:
        boolean isSame = true;
        Object realNodes[] = this.nodesList.getSelectedValues();

        if (realNodes == null || realNodes.length != nodes.size()) {
            isSame = false;
        }
        else {
            for (int i = 0; i < realNodes.length; ++i) {
                if (!nodes.contains(realNodes[i])) {
                    isSame = false;
                    break;
                }
            }
            // also must check the other way, doh:
            for (Enumeration e1 = nodes.elements(); e1.hasMoreElements(); ) {
                Object obj = e1.nextElement();
                boolean found = false;
                for (int i = 0; i < realNodes.length; ++i) {
                    if (realNodes[i].equals(obj)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    isSame = false;
                    break;
                }
            }
        }
            
        if (!isSame) {
            // update our selection...
            nodesList.clearSelection();

            if (nodes != null && nodes.size() > 0) {
                String[] data = this.currentModel.getData().getNodes();
                Arrays.sort(data);
                int selected[] = new int[nodes.size()];

                int count = 0;
                for (int i = 0; i < data.length; ++i) {
                    if (nodes.contains(data[i])) {
                        selected[count] = i;
                        ++count;
                    }
                }

                this.nodesList.setSelectedIndices(selected);
            }
        }
    }

    private void setScale(int scale,boolean fromUs) {
        if (scale != this.scaleSlider.getValue()) {
            if (scale <= this.currentModel.getMaxScale()
                && scale >= this.currentModel.getMinScale()) {
                if (fromUs) {
                    // don't want to generate a change event on the model
                    // if we didn't do it!
                    this.currentModel.setScale(scale);
                }
                this.scaleSlider.setValue(scale);

                
            }
        }
    }
    
    public void stateChanged(ChangeEvent e) {
        // XXX: for now, we only check scale and node selection,
        // since those are the only things that the interactive map
        // can change.
        
        setSelectedNodes(this.currentModel.getSelection());
        
        setScale(this.currentModel.getScale(),false);
    }
    
    private void setModel(String modelName,MapDataModel m) {
        // out-of-sight models should not generate events, but just in case:
        if (this.currentModel != null) {
            this.currentModel.removeChangeListener(this);
        }
        
        this.currentModel = m;
        this.currentModelName = modelName;
        
        // don't want to reset control in the model, just our buttons...  We 
        // can figure out what the settings for the
        // comboboxes and buttons, etc should be by what's set in the model.
        // last: tell the map about the new model:
        // no, do this first!  then the new listener in the map updates 
        // right away and redraws
        Dataset ds = (Dataset)dmodel.getDataset(this.currentModelName);
        
        this.datasetComboBox.setSelectedItem(this.currentModelName);
        
        // a bit of dynamic trickery: remove all components from indexPanel,
        // and add the necessary ones specified by this model.  If this model
        // hasn't been swapped in yet, create them and a single listener for
        // all comboboxes, then add them in descending order to the indexPanel.
        indexPanel.removeAll();
        
        Vector tv = (Vector)modelIndexComponents.get(modelName);
        Vector gbv = (Vector)modelIndexPlacements.get(modelName);
        if (tv == null || gbv == null) {
            tv = new Vector();
            modelIndexComponents.put(modelName,tv);
            gbv = new Vector();
            modelIndexPlacements.put(modelName,gbv);
            
            // populate the vector...
            String[] indices = m.getData().getIndices();
            final JComboBox[] jcArray = new JComboBox[indices.length];
            
            int cy = 0;
            
            for (int i = 0; i < indices.length; ++i) {
                JLabel jl = new JLabel();
                jl.setText(indices[i] + ":");
                jl.setFont(new java.awt.Font("Dialog",0,10));
                tv.add(jl);
                
                GridBagConstraints gc = new GridBagConstraints();
                gc.gridx = 0;
                gc.gridy = cy;
                gc.insets = new Insets(2,16,2,4);
                gc.anchor = GridBagConstraints.WEST;
                gc.fill = GridBagConstraints.HORIZONTAL;
                gc.weightx = 1.0;
                gbv.add(gc);
                
                final JComboBox jc = new JComboBox();
                // bookkeep for later, so that we can use a single listener
                // for all n comboboxen...
                jcArray[i] = jc;
                jc.setModel(new javax.swing.DefaultComboBoxModel(m.getData().getIndexValues(indices[i])));
                jc.setFont(new java.awt.Font("Dialog",1,10));
                tv.add(jc);
                
                gc = new GridBagConstraints();
                gc.gridx = 0;
                gc.gridy = cy+1;
                gc.insets = new Insets(2,16,2,2);
                gc.anchor = GridBagConstraints.WEST;
                gc.fill = GridBagConstraints.HORIZONTAL;
                //gc.weightx = 1.0;
                gc.gridwidth = 3;
                gbv.add(gc);
                
                // prev/next buttons
                JButton pb = new JButton();
                pb.setFont(new java.awt.Font("Dialog",0,8));
                pb.setText("<");
                tv.add(pb);
                pb.addActionListener(new ActionListener() {
                    final JComboBox myComboBox = jc;
                    
                    public void actionPerformed(java.awt.event.ActionEvent evt) {
                        int n = jc.getItemCount();
                        int cs = jc.getSelectedIndex();
                        if ((cs - 1) < 0) {
                            jc.setSelectedIndex(n-1);
                        }
                        else {
                            jc.setSelectedIndex(cs-1);
                        }
                    }
                });
                
                gc = new GridBagConstraints();
                gc.gridx = 1;
                gc.gridy = cy;
                gc.insets = new Insets(0,2,0,0);
                gc.anchor = GridBagConstraints.EAST;
                gbv.add(gc);
                
                JButton nb = new JButton();
                nb.setFont(new java.awt.Font("Dialog",0,8));
                nb.setText(">");
                tv.add(nb);
                nb.addActionListener(new ActionListener() {
                    final JComboBox myComboBox = jc;
                    
                    public void actionPerformed(java.awt.event.ActionEvent evt) {
                        int n = jc.getItemCount();
                        int cs = jc.getSelectedIndex();
                        if ((cs + 1) == n) {
                            jc.setSelectedIndex(0);
                        }
                        else {
                            jc.setSelectedIndex(cs+1);
                        }
                    }
                });
                
                gc = new GridBagConstraints();
                gc.gridx = 2;
                gc.gridy = cy;
                gc.insets = new Insets(0,2,0,2);
                gc.anchor = GridBagConstraints.EAST;
                gbv.add(gc);
                
                cy += 2;
            }
            
            // now create a single listener for these n comboboxen:
            //modelIndexComponents
            ActionListener tal = new java.awt.event.ActionListener() {
                JComboBox[] ijcArray = jcArray;
                
                public void actionPerformed(java.awt.event.ActionEvent evt) {
                    String[] newIndexValues = new String[ijcArray.length];
                    for (int i = 0; i < newIndexValues.length; ++i) {
                        newIndexValues[i] = (String)ijcArray[i].getSelectedItem();
                    }
                    
                    // now change the selection:
                    // actually using the value of currentModel is a bit of a race
                    // condition for fast clicks... but shouldn't be bad ever.
                    currentModel.setIndexValues(newIndexValues);
                }
            };
            
            for (int i = 0; i < indices.length; ++i) {
                jcArray[i].addActionListener(tal);
            }
            
            
        }
        // now add everything in the vector to indexPanel:
        for (int i = 0; i < tv.size(); ++i) {
            JComponent jc = (JComponent)tv.get(i);
            GridBagConstraints gc = (GridBagConstraints)gbv.get(i);

            indexPanel.add(jc,gc);
        }
        
        // set the property list:
        Vector tpv = m.getData().getProperties();
        this.primaryDisplayPropertyComboBox.setModel(new DefaultComboBoxModel(tpv));
        this.primaryDisplayPropertyComboBox.setSelectedItem(m.getCurrentProperty());
        
        
        this.nodesList.clearSelection();
        String[] nodes = this.currentModel.getData().getNodes();
        Arrays.sort(nodes);
        this.nodesList.setListData(nodes);
        
        // set up the floor combobox:
        Integer[] td = new Integer[ds.floor.length];
        for (int i = 0; i < ds.floor.length; ++i) {
            td[i] = new Integer(ds.floor[i]);
        }
        this.floorComboBox.setModel(new DefaultComboBoxModel(td));
        this.floorComboBox.setSelectedItem(new Integer(m.getFloor()));
        
        // set up the scale slider:
        this.scaleSlider.setMinimum(m.getMinScale());
        this.scaleSlider.setMaximum(m.getMaxScale());
        this.scaleSlider.setValue(m.getScale());
        if (m.getMinScale() == m.getMaxScale()) {
            this.scaleSlider.setEnabled(false);
            this.zoomInButton.setEnabled(false);
            this.zoomOutButton.setEnabled(false);
        }
        else {
            this.scaleSlider.setEnabled(true);
            this.zoomInButton.setEnabled(true);
            this.zoomOutButton.setEnabled(true);
        }
        
        this.currentModel.addChangeListener(this);
    }
    
    // <editor-fold defaultstate="collapsed" desc=" Generated Code ">//GEN-BEGIN:initComponents
    private void initComponents() {
        java.awt.GridBagConstraints gridBagConstraints;

        buttonGroup = new javax.swing.ButtonGroup();
        limitButtonGroup = new javax.swing.ButtonGroup();
        collapsablePanelContainer = new CollapsablePanelContainer();
        datasetOptionsCollapsablePanel = new CollapsablePanel("Dataset Options");
        datasetLabel = new javax.swing.JLabel();
        datasetComboBox = new JComboBox(dDCM);
        datasetParametersLabel = new javax.swing.JLabel();
        primaryDisplayPropertyLabel = new javax.swing.JLabel();
        primaryDisplayPropertyComboBox = new javax.swing.JComboBox();
        indexPanel = new javax.swing.JPanel();
        powerLevelLabel = new javax.swing.JLabel();
        powerLevelComboBox = new javax.swing.JComboBox();
        prevButton = new javax.swing.JButton();
        nextButton = new javax.swing.JButton();
        mapOptionsCollapsablePanel = new CollapsablePanel("Map Controls");
        floorLabel = new javax.swing.JLabel();
        floorComboBox = new javax.swing.JComboBox();
        scaleLabel = new javax.swing.JLabel();
        zoomOutButton = new javax.swing.JButton();
        scaleSlider = new javax.swing.JSlider();
        zoomInButton = new javax.swing.JButton();
        nodeFiltersCollapsablePanel = new CollapsablePanel("Node Filters");
        nodesLabel = new javax.swing.JLabel();
        modeAllRadioButton = new javax.swing.JRadioButton();
        selectBySrcRadioButton = new javax.swing.JRadioButton();
        selectByDstRadioButton = new javax.swing.JRadioButton();
        modeLabel = new javax.swing.JLabel();
        limitLabel = new javax.swing.JLabel();
        noneCheckBox = new javax.swing.JCheckBox();
        MSTRadioButton = new javax.swing.JRadioButton();
        otherOptionsLabel = new javax.swing.JLabel();
        noZeroLinksCheckBox = new javax.swing.JCheckBox();
        kBestNeighborsContainerPanel = new javax.swing.JPanel();
        kBestNeighborsCheckBox = new javax.swing.JCheckBox();
        nnTextField = new javax.swing.JTextField();
        thresholdContainerPanel = new javax.swing.JPanel();
        thresholdCheckBox = new javax.swing.JCheckBox();
        thresholdTextField = new javax.swing.JTextField();
        nodesListScrollPane = new javax.swing.JScrollPane();
        nodesList = new javax.swing.JList();

        setLayout(new java.awt.GridBagLayout());

        setPreferredSize(new java.awt.Dimension(250, 247));
        datasetLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        datasetLabel.setText("Dataset:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 2);
        datasetOptionsCollapsablePanel.add(datasetLabel, gridBagConstraints);

        datasetComboBox.setFont(new java.awt.Font("Dialog", 1, 10));
        datasetComboBox.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                datasetComboBoxActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 1;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 2);
        datasetOptionsCollapsablePanel.add(datasetComboBox, gridBagConstraints);

        datasetParametersLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        datasetParametersLabel.setText("Dataset parameters:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 1;
        gridBagConstraints.gridwidth = 2;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 2);
        datasetOptionsCollapsablePanel.add(datasetParametersLabel, gridBagConstraints);

        primaryDisplayPropertyLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        primaryDisplayPropertyLabel.setText("Display property:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 3;
        gridBagConstraints.gridwidth = 2;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 2);
        datasetOptionsCollapsablePanel.add(primaryDisplayPropertyLabel, gridBagConstraints);

        primaryDisplayPropertyComboBox.setFont(new java.awt.Font("Dialog", 1, 10));
        primaryDisplayPropertyComboBox.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                primaryDisplayPropertyComboBoxActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 4;
        gridBagConstraints.gridwidth = 2;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(2, 16, 2, 2);
        datasetOptionsCollapsablePanel.add(primaryDisplayPropertyComboBox, gridBagConstraints);

        indexPanel.setLayout(new java.awt.GridBagLayout());

        powerLevelLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        powerLevelLabel.setText("Power level:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 16, 2, 4);
        indexPanel.add(powerLevelLabel, gridBagConstraints);

        powerLevelComboBox.setFont(new java.awt.Font("Dialog", 1, 10));
        powerLevelComboBox.setPreferredSize(new java.awt.Dimension(60, 24));
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 1;
        gridBagConstraints.gridwidth = 3;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(2, 16, 2, 2);
        indexPanel.add(powerLevelComboBox, gridBagConstraints);

        prevButton.setFont(new java.awt.Font("Dialog", 0, 8));
        prevButton.setText("<");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 0);
        indexPanel.add(prevButton, gridBagConstraints);

        nextButton.setFont(new java.awt.Font("Dialog", 0, 8));
        nextButton.setText(">");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.insets = new java.awt.Insets(2, 0, 2, 2);
        indexPanel.add(nextButton, gridBagConstraints);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 2;
        gridBagConstraints.gridwidth = 2;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        datasetOptionsCollapsablePanel.add(indexPanel, gridBagConstraints);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.NORTHWEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(4, 4, 4, 4);
        collapsablePanelContainer.add(datasetOptionsCollapsablePanel, gridBagConstraints);

        floorLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        floorLabel.setText("Floor:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 2);
        mapOptionsCollapsablePanel.add(floorLabel, gridBagConstraints);

        floorComboBox.setFont(new java.awt.Font("Dialog", 1, 10));
        floorComboBox.setPreferredSize(new java.awt.Dimension(60, 24));
        floorComboBox.addItemListener(new java.awt.event.ItemListener() {
            public void itemStateChanged(java.awt.event.ItemEvent evt) {
                floorComboBoxItemStateChanged(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 1;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.gridwidth = 3;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.NORTHWEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 2);
        mapOptionsCollapsablePanel.add(floorComboBox, gridBagConstraints);

        scaleLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        scaleLabel.setText("Zoom:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 1;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 2);
        mapOptionsCollapsablePanel.add(scaleLabel, gridBagConstraints);

        zoomOutButton.setFont(new java.awt.Font("Dialog", 0, 10));
        zoomOutButton.setIcon(new javax.swing.ImageIcon(getClass().getResource("/minus.gif")));
        zoomOutButton.setMinimumSize(new java.awt.Dimension(16, 23));
        zoomOutButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                zoomOutButtonActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 1;
        gridBagConstraints.gridy = 1;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        mapOptionsCollapsablePanel.add(zoomOutButton, gridBagConstraints);

        scaleSlider.setMaximum(5);
        scaleSlider.setMinimum(1);
        scaleSlider.setMinorTickSpacing(1);
        scaleSlider.setPaintTicks(true);
        scaleSlider.setSnapToTicks(true);
        scaleSlider.setValue(1);
        scaleSlider.addChangeListener(new javax.swing.event.ChangeListener() {
            public void stateChanged(javax.swing.event.ChangeEvent evt) {
                scaleSliderStateChanged(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 2;
        gridBagConstraints.gridy = 1;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.NORTHWEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 2);
        mapOptionsCollapsablePanel.add(scaleSlider, gridBagConstraints);

        zoomInButton.setFont(new java.awt.Font("Dialog", 0, 10));
        zoomInButton.setIcon(new javax.swing.ImageIcon(getClass().getResource("/plus.gif")));
        zoomInButton.setMinimumSize(new java.awt.Dimension(16, 23));
        zoomInButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                zoomInButtonActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 3;
        gridBagConstraints.gridy = 1;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.EAST;
        mapOptionsCollapsablePanel.add(zoomInButton, gridBagConstraints);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 1;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.NORTHWEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(4, 4, 4, 4);
        collapsablePanelContainer.add(mapOptionsCollapsablePanel, gridBagConstraints);

        nodesLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        nodesLabel.setText("Select nodes:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 11;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.NORTHWEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 2, 2);
        nodeFiltersCollapsablePanel.add(nodesLabel, gridBagConstraints);

        buttonGroup.add(modeAllRadioButton);
        modeAllRadioButton.setFont(new java.awt.Font("Dialog", 0, 10));
        modeAllRadioButton.setMnemonic('a');
        modeAllRadioButton.setSelected(true);
        modeAllRadioButton.setLabel("Show all links");
        modeAllRadioButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                modeAllRadioButtonActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 1;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(0, 16, 0, 2);
        nodeFiltersCollapsablePanel.add(modeAllRadioButton, gridBagConstraints);

        buttonGroup.add(selectBySrcRadioButton);
        selectBySrcRadioButton.setFont(new java.awt.Font("Dialog", 0, 10));
        selectBySrcRadioButton.setMnemonic('s');
        selectBySrcRadioButton.setText("Select by source");
        selectBySrcRadioButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                selectBySrcRadioButtonActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 2;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(0, 16, 0, 2);
        nodeFiltersCollapsablePanel.add(selectBySrcRadioButton, gridBagConstraints);

        buttonGroup.add(selectByDstRadioButton);
        selectByDstRadioButton.setFont(new java.awt.Font("Dialog", 0, 10));
        selectByDstRadioButton.setMnemonic('r');
        selectByDstRadioButton.setText("Select by receiver");
        selectByDstRadioButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                selectByDstRadioButtonActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 3;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(0, 16, 0, 2);
        nodeFiltersCollapsablePanel.add(selectByDstRadioButton, gridBagConstraints);

        modeLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        modeLabel.setText("Mode:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 0, 2);
        nodeFiltersCollapsablePanel.add(modeLabel, gridBagConstraints);

        limitLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        limitLabel.setText("Limit by:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 5;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 0, 2);
        nodeFiltersCollapsablePanel.add(limitLabel, gridBagConstraints);

        limitButtonGroup.add(noneCheckBox);
        noneCheckBox.setFont(new java.awt.Font("Dialog", 0, 10));
        noneCheckBox.setSelected(true);
        noneCheckBox.setText("None");
        noneCheckBox.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                noneCheckBoxActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 6;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(0, 15, 0, 2);
        nodeFiltersCollapsablePanel.add(noneCheckBox, gridBagConstraints);

        buttonGroup.add(MSTRadioButton);
        MSTRadioButton.setFont(new java.awt.Font("Dialog", 0, 10));
        MSTRadioButton.setText("Min Spanning Tree");
        MSTRadioButton.setEnabled(false);
        MSTRadioButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                MSTRadioButtonActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 4;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(0, 16, 0, 2);
        nodeFiltersCollapsablePanel.add(MSTRadioButton, gridBagConstraints);

        otherOptionsLabel.setFont(new java.awt.Font("Dialog", 0, 10));
        otherOptionsLabel.setText("Other options:");
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 9;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(2, 2, 0, 2);
        nodeFiltersCollapsablePanel.add(otherOptionsLabel, gridBagConstraints);

        noZeroLinksCheckBox.setFont(new java.awt.Font("Dialog", 0, 10));
        noZeroLinksCheckBox.setSelected(true);
        noZeroLinksCheckBox.setText("Never show 0% links");
        noZeroLinksCheckBox.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                noZeroLinksCheckBoxActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 10;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.insets = new java.awt.Insets(0, 16, 0, 2);
        nodeFiltersCollapsablePanel.add(noZeroLinksCheckBox, gridBagConstraints);

        kBestNeighborsContainerPanel.setLayout(new java.awt.GridBagLayout());

        limitButtonGroup.add(kBestNeighborsCheckBox);
        kBestNeighborsCheckBox.setFont(new java.awt.Font("Dialog", 0, 10));
        kBestNeighborsCheckBox.setText("k best neighbors");
        kBestNeighborsCheckBox.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                kBestNeighborsCheckBoxActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        kBestNeighborsContainerPanel.add(kBestNeighborsCheckBox, gridBagConstraints);

        nnTextField.setFont(new java.awt.Font("Dialog", 0, 10));
        nnTextField.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
        nnTextField.setText("3");
        nnTextField.setMaximumSize(new java.awt.Dimension(35, 17));
        nnTextField.setPreferredSize(new java.awt.Dimension(40, 17));
        nnTextField.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                nnTextFieldActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 1;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(0, 2, 0, 0);
        kBestNeighborsContainerPanel.add(nnTextField, gridBagConstraints);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 7;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.insets = new java.awt.Insets(0, 15, 0, 2);
        nodeFiltersCollapsablePanel.add(kBestNeighborsContainerPanel, gridBagConstraints);

        thresholdContainerPanel.setLayout(new java.awt.GridBagLayout());

        limitButtonGroup.add(thresholdCheckBox);
        thresholdCheckBox.setFont(new java.awt.Font("Dialog", 0, 10));
        thresholdCheckBox.setText("links above");
        thresholdCheckBox.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                thresholdCheckBoxActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        thresholdContainerPanel.add(thresholdCheckBox, gridBagConstraints);

        thresholdTextField.setFont(new java.awt.Font("Dialog", 0, 10));
        thresholdTextField.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
        thresholdTextField.setText("70");
        thresholdTextField.setPreferredSize(new java.awt.Dimension(40, 17));
        thresholdTextField.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                thresholdTextFieldActionPerformed(evt);
            }
        });

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 1;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.WEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(0, 2, 0, 0);
        thresholdContainerPanel.add(thresholdTextField, gridBagConstraints);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 8;
        gridBagConstraints.fill = java.awt.GridBagConstraints.HORIZONTAL;
        gridBagConstraints.insets = new java.awt.Insets(0, 15, 0, 2);
        nodeFiltersCollapsablePanel.add(thresholdContainerPanel, gridBagConstraints);

        nodesList.setFont(new java.awt.Font("Dialog", 0, 10));
        nodesList.addListSelectionListener(new javax.swing.event.ListSelectionListener() {
            public void valueChanged(javax.swing.event.ListSelectionEvent evt) {
                nodesListValueChanged(evt);
            }
        });

        nodesListScrollPane.setViewportView(nodesList);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 12;
        gridBagConstraints.fill = java.awt.GridBagConstraints.BOTH;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.NORTHWEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.weighty = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(2, 16, 2, 2);
        nodeFiltersCollapsablePanel.add(nodesListScrollPane, gridBagConstraints);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 2;
        gridBagConstraints.fill = java.awt.GridBagConstraints.BOTH;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.NORTHWEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.weighty = 1.0;
        gridBagConstraints.insets = new java.awt.Insets(4, 4, 4, 4);
        collapsablePanelContainer.add(nodeFiltersCollapsablePanel, gridBagConstraints);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.fill = java.awt.GridBagConstraints.BOTH;
        gridBagConstraints.anchor = java.awt.GridBagConstraints.NORTHWEST;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.weighty = 1.0;
        add(collapsablePanelContainer, gridBagConstraints);

    }// </editor-fold>//GEN-END:initComponents

    private void zoomInButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_zoomInButtonActionPerformed
        this.currentModel.setScale(this.currentModel.getScale() + 1);
    }//GEN-LAST:event_zoomInButtonActionPerformed

    private void zoomOutButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_zoomOutButtonActionPerformed
        this.currentModel.setScale(this.currentModel.getScale() - 1);
    }//GEN-LAST:event_zoomOutButtonActionPerformed

    private void nodesListValueChanged(javax.swing.event.ListSelectionEvent evt) {//GEN-FIRST:event_nodesListValueChanged
        // check if the selection changed;
        if (!nodesList.getValueIsAdjusting()) {
            // safe
            Object objs[] = nodesList.getSelectedValues();
            Vector tmp = new Vector();
            for (int i = 0; i < objs.length; ++i) {
                tmp.add(objs[i]);
            }
            this.currentModel.setSelection(tmp);
        }
    }//GEN-LAST:event_nodesListValueChanged

    private void floorComboBoxItemStateChanged(java.awt.event.ItemEvent evt) {//GEN-FIRST:event_floorComboBoxItemStateChanged
        this.currentModel.setFloor(((Integer)floorComboBox.getSelectedItem()).intValue());
    }//GEN-LAST:event_floorComboBoxItemStateChanged

    private void scaleSliderStateChanged(javax.swing.event.ChangeEvent evt) {//GEN-FIRST:event_scaleSliderStateChanged
        if (!this.scaleSlider.getValueIsAdjusting()) {
            int s = scaleSlider.getValue();
            this.currentModel.setScale(s);
        }
    }//GEN-LAST:event_scaleSliderStateChanged
    
    private void primaryDisplayPropertyComboBoxActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_primaryDisplayPropertyComboBoxActionPerformed
        this.currentModel.setCurrentProperty((String)this.primaryDisplayPropertyComboBox.getSelectedItem());
    }//GEN-LAST:event_primaryDisplayPropertyComboBoxActionPerformed

    private void noZeroLinksCheckBoxActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_noZeroLinksCheckBoxActionPerformed
        boolean cval = this.currentModel.getOption(MapDataModel.OPTION_NO_ZERO_LINKS);
        if (noZeroLinksCheckBox.isSelected()) {
            if (!cval) {
                this.currentModel.setOption(MapDataModel.OPTION_NO_ZERO_LINKS, MapDataModel.OPTION_SET);
            }
        }
        else {
            if (cval) {
                this.currentModel.setOption(MapDataModel.OPTION_NO_ZERO_LINKS, MapDataModel.OPTION_UNSET);
            }
        }
    }//GEN-LAST:event_noZeroLinksCheckBoxActionPerformed

    private void MSTRadioButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_MSTRadioButtonActionPerformed
        if (MSTRadioButton.isSelected() && !(currentModel.getMode() == MapDataModel.MODE_MST)) {
            currentModel.setMode(MapDataModel.MODE_MST);
            
            nodesList.setEnabled(false);
            // also want to disable all the limit checkboxes, since limits are meaningless here
            kBestNeighborsCheckBox.setEnabled(false);
            noneCheckBox.setEnabled(false);
            thresholdCheckBox.setEnabled(false);
            
            // ehhhh...
            //nnTextField.setEnabled(false);
            //thresholdTextField.setEnabled(false);
        }
    }//GEN-LAST:event_MSTRadioButtonActionPerformed

    private void thresholdTextFieldActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_thresholdTextFieldActionPerformed
        Float threshold = null;
        boolean error = false;
        try {
            threshold = new Float(Float.parseFloat(this.thresholdTextField.getText()));
        }
        catch (NumberFormatException e) {
            //e.printStackTrace();
            error = true;
        }
        
        if (!currentModel.setThreshold(threshold)) {
            error = true;
        }
        
        if (error) {
            JOptionPane.showMessageDialog(this.getParent(),
                "Please enter a floating point number!",
                "Number Format Error",
                JOptionPane.ERROR_MESSAGE);
            thresholdTextField.setText(""+currentModel.getThreshold());
        }
    }//GEN-LAST:event_thresholdTextFieldActionPerformed

    private void thresholdCheckBoxActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_thresholdCheckBoxActionPerformed
        if (thresholdCheckBox.isSelected() && !(currentModel.getLimit() == MapDataModel.LIMIT_THRESHOLD)) {
            currentModel.setLimit(MapDataModel.LIMIT_THRESHOLD);
            
            nnTextField.setEnabled(false);
            thresholdTextField.setEnabled(true);
        }
    }//GEN-LAST:event_thresholdCheckBoxActionPerformed

    private void nnTextFieldActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_nnTextFieldActionPerformed
        int neighbors = -1;
        boolean error = false;
        try {
            neighbors = Integer.parseInt(this.nnTextField.getText());
        }
        catch (NumberFormatException e) {
            //e.printStackTrace();
            error = true;
        }
        
        if (!currentModel.setNeighborCount(neighbors)) {
            error = true;
        }
        
        if (error) {
            JOptionPane.showMessageDialog(this.getParent(),
                "Please enter a positive integer greater than zero!",
                "Number Format Error",
                JOptionPane.ERROR_MESSAGE);
            nnTextField.setText(""+currentModel.getNeighborCount());
        }
    }//GEN-LAST:event_nnTextFieldActionPerformed

    private void kBestNeighborsCheckBoxActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_kBestNeighborsCheckBoxActionPerformed
        if (kBestNeighborsCheckBox.isSelected() && !(currentModel.getLimit() == MapDataModel.LIMIT_N_BEST_NEIGHBOR)) {
            currentModel.setLimit(MapDataModel.LIMIT_N_BEST_NEIGHBOR);
            
            nnTextField.setEnabled(true);
            thresholdTextField.setEnabled(false);
        }
    }//GEN-LAST:event_kBestNeighborsCheckBoxActionPerformed

    private void noneCheckBoxActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_noneCheckBoxActionPerformed
        if (noneCheckBox.isSelected() && !(currentModel.getLimit() == MapDataModel.LIMIT_NONE)) {
            currentModel.setLimit(MapDataModel.LIMIT_NONE);
            
            nnTextField.setEnabled(false);
            thresholdTextField.setEnabled(false);
        }
    }//GEN-LAST:event_noneCheckBoxActionPerformed

    private void selectByDstRadioButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_selectByDstRadioButtonActionPerformed
        if (selectByDstRadioButton.isSelected() && !(currentModel.getMode() == MapDataModel.MODE_SELECT_DST)) {
            currentModel.setMode(MapDataModel.MODE_SELECT_DST);
            
            nodesList.setEnabled(true);
            
            kBestNeighborsCheckBox.setEnabled(true);
            noneCheckBox.setEnabled(true);
            thresholdCheckBox.setEnabled(true);
        }
    }//GEN-LAST:event_selectByDstRadioButtonActionPerformed

    private void selectBySrcRadioButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_selectBySrcRadioButtonActionPerformed
        if (selectBySrcRadioButton.isSelected() && !(currentModel.getMode() == MapDataModel.MODE_SELECT_SRC)) {
            currentModel.setMode(MapDataModel.MODE_SELECT_SRC);
            
            nodesList.setEnabled(true);
            
            kBestNeighborsCheckBox.setEnabled(true);
            noneCheckBox.setEnabled(true);
            thresholdCheckBox.setEnabled(true);
        }
    }//GEN-LAST:event_selectBySrcRadioButtonActionPerformed

    private void modeAllRadioButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_modeAllRadioButtonActionPerformed
        if (modeAllRadioButton.isSelected() && !(currentModel.getMode() == MapDataModel.MODE_ALL)) {
            currentModel.setMode(MapDataModel.MODE_ALL);
            
            nodesList.setEnabled(false);
            
            kBestNeighborsCheckBox.setEnabled(true);
            noneCheckBox.setEnabled(true);
            thresholdCheckBox.setEnabled(true);
        }
    }//GEN-LAST:event_modeAllRadioButtonActionPerformed

    private void datasetComboBoxActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_datasetComboBoxActionPerformed
        String modelName = (String)datasetComboBox.getSelectedItem();
        Dataset ds = (Dataset)dmodel.getDataset(modelName);
        this.dmodel.setCurrentModel(modelName);
    }//GEN-LAST:event_datasetComboBoxActionPerformed
    
    
    // Variables declaration - do not modify//GEN-BEGIN:variables
    private javax.swing.JRadioButton MSTRadioButton;
    private javax.swing.ButtonGroup buttonGroup;
    private CollapsablePanelContainer collapsablePanelContainer;
    private javax.swing.JComboBox datasetComboBox;
    private javax.swing.JLabel datasetLabel;
    private CollapsablePanel datasetOptionsCollapsablePanel;
    private javax.swing.JLabel datasetParametersLabel;
    private javax.swing.JComboBox floorComboBox;
    private javax.swing.JLabel floorLabel;
    private javax.swing.JPanel indexPanel;
    private javax.swing.JCheckBox kBestNeighborsCheckBox;
    private javax.swing.JPanel kBestNeighborsContainerPanel;
    private javax.swing.ButtonGroup limitButtonGroup;
    private javax.swing.JLabel limitLabel;
    private CollapsablePanel mapOptionsCollapsablePanel;
    private javax.swing.JRadioButton modeAllRadioButton;
    private javax.swing.JLabel modeLabel;
    private javax.swing.JButton nextButton;
    private javax.swing.JTextField nnTextField;
    private javax.swing.JCheckBox noZeroLinksCheckBox;
    private CollapsablePanel nodeFiltersCollapsablePanel;
    private javax.swing.JLabel nodesLabel;
    private javax.swing.JList nodesList;
    private javax.swing.JScrollPane nodesListScrollPane;
    private javax.swing.JCheckBox noneCheckBox;
    private javax.swing.JLabel otherOptionsLabel;
    private javax.swing.JComboBox powerLevelComboBox;
    private javax.swing.JLabel powerLevelLabel;
    private javax.swing.JButton prevButton;
    private javax.swing.JComboBox primaryDisplayPropertyComboBox;
    private javax.swing.JLabel primaryDisplayPropertyLabel;
    private javax.swing.JLabel scaleLabel;
    private javax.swing.JSlider scaleSlider;
    private javax.swing.JRadioButton selectByDstRadioButton;
    private javax.swing.JRadioButton selectBySrcRadioButton;
    private javax.swing.JCheckBox thresholdCheckBox;
    private javax.swing.JPanel thresholdContainerPanel;
    private javax.swing.JTextField thresholdTextField;
    private javax.swing.JButton zoomInButton;
    private javax.swing.JButton zoomOutButton;
    // End of variables declaration//GEN-END:variables
    
}
