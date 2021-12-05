# INSTALLATION CLOUDLAB

## Installation through EMULAB code (For future developers): 

Emulab code repo link: https://gitlab.flux.utah.edu/emulab/emulab-devel/-/tree/master

1. To run the cloudlab code we must clone the emulab codebase onto a linux box (i.e. code doesn't work on windows). 
2. Once the code is cloned. You might want to create a new branch and make the changes, to add esi nodes access in cloudlab code.
3. See steps in below installation guide to setup the environment, for MySql, etc.
4. Write code to access the ESI nodes.

## Installation of Cloudlab code with code accesing Mock ESI:

Code repo link: https://github.com/talhamehboob10/CloudLabonESI/


The configured code pushed into GIT has build path as per the local linux development setup for our team. To setup for your local linux box you must perform the below steps.

### Steps to setup the code:

1. Clone the above repo. Most files in the repo are all input files, i.e. the variables need to be configured with values pertaining to the environment we are running them in.
2. Create a 'build' folder (i.e. could be named anything, we named it build_aish if you want to check for reference).
3. `cd` into the build folder and run the below command. This would configure the values for all the input files and these files would be created with the build folder mention as `prefix` in below command.

    `../configure --prefix=/path-to-your-build-folder --with-TBDEFS=../defs-cloudlab-umass`  
4. You can try running `make` but that isn't necessary at this stage as we don't want a deployable artifact for the emulab code.
5. Our main aim is to run the power file. Hence give a try running the power file. You will get errors saying the file doesn't exist in the @INC. 
6. To fix above mentioned error, we must add the path to the `db` folder and certain other folders from which we run certain files.

    `use lib "/path-to-your-build-folder";`
    

    `use lib "/path-to-your-build-folder/db";`
    

    `use lib "/path-to-your-build-folder/tbsetup";`


    `use lib "/path-to-your-build-folder/clientside/xmlrpc";`


    `use lib "/path-to-your-build-folder/event/stated";`


    `use lib "/path-to-your-build-folder/event";`


    `use lib "/path-to-your-build-folder/clientside/lib/event";`
    
1. Running the configure might not copy all files, some might be missing from the build folder. You can find out which files are those by running the below command.

    `diff --brief --recursive /users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/ /path-to-your-build-folder/`
    
These files are as follows, copy them from build_aish and paste it in your build folder in the same directory:

i. All files in the directory `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/clientside/lib/event/`

ii. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/db/Brand.pm` file.

iii. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/db/libEmulab.pm` file.

iv. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/event/stated/StateWait.pm` file.

v. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/libtblog_simple.pm` file.

vi. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_apc.pm` file.

vii. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_esi.pm` file.

viii. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_ibmbc.pm` file.

ix. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_icebox.pm` file.

x. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_ilo.pm` file.

xi. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_ipmi.pm` file.

xii. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_powduino.pm` file.

xiii. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_racktivity.pm` file.

xiv. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_raritan.pm` file.

xv. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_ue.pm` file.

#### Configure Variables

In addition to copying the file, update the $TB variable value (which will be the path to this new build folder. ) in to the given files which are copied to the new build folder:

1. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/db/Brand.pm`
2. `/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/tbsetup/power_ibmbc.pm`

The update would look like this 
`my $TB = /path-to-your-build-folder/`
