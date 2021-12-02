FROM ruby:2.7

ADD . /src

WORKDIR /src

RUN bundle install

CMD ["./hello_world.rb"]
