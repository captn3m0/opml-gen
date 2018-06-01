FROM ruby:alpine
MAINTAINER Nemo <opml.docker@captnemo.in>

WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN apk add --no-cache build-base && bundle install && apk del build-base
COPY . /app

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/bundle", "exec", "rackup", "-E", "production", "-p", "80"]
