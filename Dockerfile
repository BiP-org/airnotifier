FROM python:3.11
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive TERM=linux
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

EXPOSE 8801

# Configure APT
RUN echo "debconf debconf/frontend select ${DEBIAN_FRONTEND}" | debconf-set-selections \
    && echo 'APT::Install-Recommends "false";' | tee /etc/apt/apt.conf.d/99install-recommends \
    && echo 'APT::Get::Assume-Yes "true";' | tee /etc/apt/apt.conf.d/99assume-yes \
    && sed -Ei 's|^(DPkg::Pre-Install-Pkgs .*)|#\1|g' /etc/apt/apt.conf.d/70debconf \
    && debconf-show debconf

RUN apt-get update -q -y && \
    apt-get install -q -y --no-install-recommends git ca-certificates python3-dev python3 python3-dns


RUN pip3 install pipenv

COPY . /airnotifier
RUN mkdir -p /var/airnotifier/pemdir && \
    mkdir -p /var/log/airnotifier

VOLUME ["/airnotifier", "/var/log/airnotifier", "/var/airnotifier/pemdir"]
WORKDIR /airnotifier

RUN pipenv install --deploy

ADD start.sh /airnotifier
RUN chmod a+x /airnotifier/start.sh
RUN chmod a+x /airnotifier/install.py
RUN chmod a+x /airnotifier/app.py
ENTRYPOINT /airnotifier/start.sh
