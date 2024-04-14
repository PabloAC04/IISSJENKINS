FROM jenkins/jenkins
USER root
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv && \
    ln -s /usr/bin/python3 /usr/bin/python

RUN apt-get update && apt-get install -y python3 python3-pip
RUN python3 -m venv /opt/venv
RUN . /opt/venv/bin/activate && pip install pytest
ENV PATH="/opt/venv/bin:$PATH"

USER jenkins
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow"
