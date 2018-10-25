FROM docker.elastic.co/elasticsearch/elasticsearch:6.4.2
ENV REGION us-east-1
ADD elasticsearch.yml /usr/share/elasticsearch/config/
USER root
RUN chown elasticsearch:elasticsearch config/elasticsearch.yml
USER elasticsearch
WORKDIR /usr/share/elasticsearch
RUN bin/elasticsearch-plugin install discovery-ec2 --batch && bin/elasticsearch-plugin install repository-s3 --batch && sed -e '/^-Xm/s/^/#/g' -i /usr/share/elasticsearch/config/jvm.options
