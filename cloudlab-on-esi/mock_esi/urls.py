from django.urls import path
from .views import index, nodeCommands

urlpatterns = [
     path('', index, name='home'),
    path('view/<int:id>/', nodeCommands, name='node'),

]