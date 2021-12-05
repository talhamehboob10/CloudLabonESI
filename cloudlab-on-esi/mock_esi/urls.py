from django.urls import path
from .views import index, nodeCommands, index_terminal, powerOn

urlpatterns = [
    path('', index, name='home'),
    path('view/<int:id>/', nodeCommands, name='node'),
    path('terminal/', index_terminal, name='index_terminal'),
    path('view/poweron/<int:id>/', powerOn, name='poweron')

]