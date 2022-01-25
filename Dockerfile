FROM ruby:2.7

ADD . /src

WORKDIR /src

RUN bundle lock
RUN bundle config set deployment 'true'
RUN bundle install

CMD ["bundle",  "exec",  "./index.rb"]
