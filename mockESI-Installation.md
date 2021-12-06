# Installation of Mock ESI on Local

1. We have used Django MVT framework to create the Mock ESI. 
In order to set up the mock ESI on your local machine follow the mentioned installation steps:

    -   Install Django using *pip*
    
        Mac: 
        ```
        pip3 install django
        ```
        Windows:
        ```
        pip install django
        ```
   -    Clone the repository to get the latest Mock ESI codebase
     
        Mac: 
        ```
        git clone https://github.com/talhamehboob10/CloudLabonESI.git
        ```
        Windows:
        ```
        git clone https://github.com/talhamehboob10/CloudLabonESI.git
        ```   
        
   -   Change directory to the working directory of cloudlab
    
        Mac: 
        ```
        cd cloudlab-on-esi
        ```
        Windows:
        ```
        cd cloudlab-on-esi
        ```  
        
   -    Open this project on your preferred IDE. We have used PyCharm here.
       Navigate to the folder cloudlab-on-esi.
       
   -    Open terminal on the IDE and deactivate the virtual environment if you are in one. To deactivate simply run the command deactivate.
    
           ```
           (venv)C:\CS6620\Project\cloudlab-on-esi>deactivate
           C:\CS6620\Project\cloudlab-on-esi>
           ```
        
   -   Install the required libraries to run the project
    
            Mac: 
            ```
            pip3 install requests
            ```
            Windows:
            ```
            pip install requests
            ```  
            Mac: 
            ```
            pip3 install djangorestframework
            ```
            Windows:
            ```
            pip install djangorestframework
            ```  
        
2.     Now we are ready with all the prerequisites to run the project

    -    Run the following command in terminal to start the Mock ESI 
        
            Mac: 
            ```
            python manage.py runserver
            ```
            
            Windows:
            ```
            python manage.py runserver
            ```  

