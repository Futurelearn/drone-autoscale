FROM ruby:2.5.1-slim

LABEL Name=futurelearn/drone-autoscale

WORKDIR /opt

COPY . .

ENV PATH="/opt/bin:${PATH}"

RUN bundle install --without=test --without=development

ENTRYPOINT ["drone-autoscale"]
CMD ["agent"]
