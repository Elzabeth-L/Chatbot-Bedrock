FROM public.ecr.aws/lambda/python:3.13

RUN dnf -y --releasever=latest update \
    && dnf clean all \
    && rm -rf /var/cache/dnf

COPY handler.py ${LAMBDA_TASK_ROOT}/handler.py

CMD ["handler.handler"]
