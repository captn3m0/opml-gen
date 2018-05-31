FROM ruby:alpine
MAINTAINER Nemo <opml.docker@captnemo.in>

WORKDIR /app

COPY Gemfile Gemfile.lock /app/
RUN apk add --no-cache build-base
RUN bundle install
COPY . /app

ENTRYPOINT ["bundle exec rackup"]
