FROM public.ecr.aws/lambda/python:3.13

RUN dnf upgrade -y \
    && dnf clean all \
    && rm -rf /var/cache/dnf

COPY handler.py ${LAMBDA_TASK_ROOT}/handler.py

CMD ["handler.handler"]
