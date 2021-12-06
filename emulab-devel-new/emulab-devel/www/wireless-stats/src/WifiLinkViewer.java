/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
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

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.util.*;

//class ImageObserverImpl implements java.awt.image.ImageObserver {
//    public boolean updateImage(Image img, int infoflags, int x, int y, int width, int height) {
//        System.out.println("w = "+width+",h = "+height);
//    }
//}

public class WifiLinkViewer extends javax.swing.JFrame {

    private Image bgImage;
    private java.awt.image.ImageObserver io;
    private Hashtable datasets;
    private Hashtable mapImages;
    
    public WifiLinkViewer(String dataFile) {
        this.datasets = new Hashtable();
        this.mapImages = new Hashtable();
        
        io = new java.awt.Component() {
            public boolean updateImage(Image img, int infoflags, int x, int y, int width, int height) {
                System.out.println("w = "+width+",h = "+height);
                
                return true;
            }
        };
        
        bgImage = Toolkit.getDefaultToolkit().getImage("../meb3fl-2.jpg");
        mapImages.put("Floor4/WSN",bgImage);
        
        try {
            MediaTracker tracker = new MediaTracker(this);
            tracker.addImage(bgImage, 0);
            tracker.waitForID(0);
            //System.out.println("width = "+bgImage.getWidth(io));
        }
        catch (InterruptedException ex) {
            ex.printStackTrace();
        }
        
        // in the applet, we'll read in the possible datasets and 
        
        WirelessData defaultData = null;
        NodePosition defaultPositions = null;
        MapDataModel defaultModel = null;
        String defaultDatasetName = "Floor4/WSN";
        
        try {
	    if ( dataFile == null ) dataFile = "../wifi_test.log"; // Default.
            defaultData = ILEStats.parseDumpFile(dataFile, "pcwf");
            defaultPositions = NodePositions.parseFile("../wifi_positions");
            
            defaultModel = new MapDataModel(defaultData,defaultPositions);
            datasets.put(defaultDatasetName,defaultModel);
        }
        catch (Exception e) {
            e.printStackTrace();
            System.exit(-2);
        }
        
        initComponents();
        
        
        
        ;
        
    }
    
    // <editor-fold defaultstate="collapsed" desc=" Generated Code ">//GEN-BEGIN:initComponents
    private void initComponents() {
        java.awt.GridBagConstraints gridBagConstraints;

        nodeMapScrollPane = new javax.swing.JScrollPane();
        nodeMapPanel = new NodeMapPanel();
        //nodeMapPanel.setBackgroundImage(bgImage);
        //nodeMapPanel.setPositions(positions);
        //nodeMapPanel.setILEStats(model);
        controlPanel = new ControlPanel(datasets,mapImages,nodeMapPanel);

        getContentPane().setLayout(new java.awt.GridBagLayout());

        setDefaultCloseOperation(javax.swing.WindowConstants.EXIT_ON_CLOSE);
        nodeMapScrollPane.setBackground(new java.awt.Color(255, 255, 255));
        nodeMapScrollPane.setViewportView(nodeMapPanel);

        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.gridx = 0;
        gridBagConstraints.gridy = 0;
        gridBagConstraints.fill = java.awt.GridBagConstraints.BOTH;
        gridBagConstraints.weightx = 1.0;
        gridBagConstraints.weighty = 1.0;
        getContentPane().add(nodeMapScrollPane, gridBagConstraints);

        controlPanel.setPreferredSize(new java.awt.Dimension(200, 247));
        gridBagConstraints = new java.awt.GridBagConstraints();
        gridBagConstraints.fill = java.awt.GridBagConstraints.VERTICAL;
        getContentPane().add(controlPanel, gridBagConstraints);

        pack();
    }
    // </editor-fold>//GEN-END:initComponents
        
    public static void main(final String args[]) {
        java.awt.EventQueue.invokeLater(new Runnable() {
            public void run() {
		String dataFile = null;
		if ( args.length > 0 ) dataFile = args[0];
                new WifiLinkViewer(dataFile).setVisible(true);
            }
        });
    }
    
    // Variables declaration - do not modify//GEN-BEGIN:variables
    private ControlPanel controlPanel;
    private NodeMapPanel nodeMapPanel;
    private javax.swing.JScrollPane nodeMapScrollPane;
    // End of variables declaration//GEN-END:variables
    
}
