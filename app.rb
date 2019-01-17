# frozen_string_literal: true

require 'dotenv'
require 'sinatra/base'
require 'sinatra/reloader'
require 'octokit'
require 'redis'
require 'json'
require './opml'

Octokit.auto_paginate = true

class MyApp < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    also_reload 'opml.rb'
    Dotenv.load
  end

  configure do
    set :r, Redis.new(url: ENV.fetch('REDIS_URL'))
    set :client, Octokit::Client.new(
      client_id: ENV.fetch('GITHUB_CLIENT_ID'),
      client_secret: ENV.fetch('GITHUB_CLIENT_SECRET'),
      per_page: 100,
      auto_traversal: true,
      auto_paginate: true
    )
  end

  def get_sec_opml(stocks = %w[AAPL GOOG])
    opml = OPML.new do
      @title = "SEC Filings for #{stocks.join}"
      # TODO: Fix this
      @date_created = Time.now.rfc822
      @date_modified = Time.now.rfc822
      @owner_name = 'Generated by Nemo'
    end
    stocks.each do |stock|
      title = "SEC: #{stock}"
      html_url = "https://rss-bridge.bb8.fun/?action=display&bridge=StockFilings&ticker=#{stock}&format=Html"
      rss_url  = "https://rss-bridge.bb8.fun/?action=display&bridge=StockFilings&ticker=#{stock}&format=Atom"
      opml.add_outline(
        text: title, description: "SEC Filings for #{stock}", html_url: html_url,
        xml_url: rss_url, title: title,
        type: 'rss', version: 'RSS2'
      )
    end

    filename = 'sec.opml'

    response.headers['Content-Disposition'] = "attachment; filename=#{filename};"
    response.headers['Content-Type'] = 'application/octet-stream'
    response.headers['Content-Transfer-Encoding'] = 'binary'

    opml.xml 'Stock Filings'
  end

  def get_starred_repos_from_cache(user)
    from_cache = settings.r.get "#{user}.repos"
    if from_cache
      time = settings.r.get "#{user}.repos.time" || Time.now.to_i
      return [JSON.parse(from_cache), time]
    end
    repos = []
    starred = settings.client.starred(user)

    starred.each do |repo|
      repos.push repo[:full_name]
    end

    time = Time.now.to_i
    settings.r.set "#{user}.repos", repos
    settings.r.set "#{user}.repos.time", time
    # Keep the starred repo list for 1 day
    settings.r.expire "#{user}.repos", 60 * 60 * 24
    [repos, time]
  end

  get '/' do
    File.read File.join 'public', 'index.html'
  end

  post '/submit/:type' do
    if params[:type] == 'github'
      username = params[:username]
      redirect "/github/#{username}/starred.opml"
    elsif params[:type] == 'sec'
      get_sec_opml params[:stocks].split(',')
    else
      'Invalid Type'
    end
  end

  get '/github/:user/starred.opml' do
    user = params[:user]
    repos, time = get_starred_repos_from_cache(user)
    opml = OPML.new do
      @title = "Releases: #{user}/starred"
      # TODO: Fix this
      @date_created = Time.now.rfc822
      @date_modified = Time.now.rfc822
      @owner_name = user
    end
    repos.each do |r|
      title = "#{r} Release Notes"
      html_url = "https://github.com/#{r}/releases"
      rss_url  = "#{html_url}.atom"
      opml.add_outline(
        text: title, description: "#{r}/releases", html_url: html_url,
        xml_url: rss_url, title: title,
        type: 'rss', version: 'RSS2'
      )
    end

    filename = "#{user}-starred-releases.opml"

    response.headers['Content-Disposition'] = "attachment; filename=#{filename};"
    response.headers['Content-Type'] = 'application/octet-stream'
    response.headers['Content-Transfer-Encoding'] = 'binary'

    opml.xml 'GitHub Releases'
  end
end
