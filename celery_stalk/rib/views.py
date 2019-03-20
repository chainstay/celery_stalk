# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from celery.result import AsyncResult
from django.http import HttpResponse
from django.shortcuts import render

from .tasks import grow_celery


def grow_stalk(request):
    task = grow_celery.delay()
    return HttpResponse('Celery is growing, <a href="/rib/tasks/?uid={uid}"> '
                        'click here</a> to see it!'.format(uid=task.id))


def task(request):
    uid = request.GET.get('uid')
    task = AsyncResult(uid)
    if task.ready():
        return HttpResponse('<h1 style="font-size: 10rem">{}</h1>'.format(unicode(task.result)))

    return HttpResponse('Sit tight... it\'s still growing')
