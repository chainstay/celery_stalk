# -*- coding: utf-8 -*-
from __future__ import absolute_import, unicode_literals
import time
import random

from celery import shared_task


@shared_task
def grow_celery():
    time.sleep(random.randrange(2, 5))
    return '🥦'
