FROM python:3.10-slim

WORKDIR /srv/hal

RUN pip install torch redis numpy

COPY . /srv/hal

CMD ["python", "-m", "mesh.rl.ppo.trainer"]
