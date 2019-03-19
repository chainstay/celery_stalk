from django.conf.urls import url
from . import views

urlpatterns = [
    url('^grow', views.grow_stalk),
    url('^task', views.task),
]
