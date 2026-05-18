FROM python:3.10-slim

WORKDIR /srv/hal

# system deps
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# python deps
COPY requirements.txt /srv/hal/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# copy full system
COPY . /srv/hal

ENV PYTHONPATH=/srv/hal

CMD ["bash"]
