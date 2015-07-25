#!/usr/bin/env ruby
require 'octokit'

git_token = ENV['GITHUB_TOKEN']
# Provide authentication credentials
client = Octokit::Client.new(access_token: git_token)

Octokit.auto_paginate = true

## Change this if you want to run more than one set of issue widgets
event_name = 'git_issues_labeled_defects'

## Create an array to hold our data points
points = []

## One hours worth of data for, seed 60 empty points (rickshaw acts funny
#if you don't).
(0..60).each do |a|
  points << { x: a, y: 0.01 }
end

## Grab the last x value
last_x = points.last[:x]

SCHEDULER.every '10s', first_in: 0 do |job|
  begin
    # Fetch the current user
    results = client.user_events(client.user.login)

    closed_issues = 0

    results.each do |event|
      closed_issues += 1 if event.payload.action == 'closed'
    end

    ## Drop the first point value and increment x by 1
    points.shift
    last_x += 1

    ## Push the most recent point value
    points << { x: last_x, y: closed_issues  }

    send_event(event_name, { text: closed_issues, points:points })

  rescue Octokit::Error
    puts "\e[33mFor the GitHub issues widget to work, you need to put in your GitHub authorization token.\e[0m"
  end
end # SCHEDULER
