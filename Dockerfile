FROM ruby:alpine
MAINTAINER Nemo <opml.docker@captnemo.in>

WORKDIR /app

COPY Gemfile Gemfile.lock /app/
RUN bundle install
COPY . /app

ENTRYPOINT ["bundle exec rackup"]
