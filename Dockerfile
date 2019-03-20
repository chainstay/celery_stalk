FROM python:2

RUN apt-get update && apt-get install -y postgresql-client

ADD ./celery_stalk/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

RUN groupadd -g 999 appuser && \
  useradd -r -u 999 -g appuser appuser
USER appuser

ADD ./celery_stalk /app
ADD ./docker_entrypoint.sh /

WORKDIR /app

ENTRYPOINT [ "/docker_entrypoint.sh"]
