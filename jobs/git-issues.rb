#!/usr/bin/env ruby
require 'time'
require 'rest-client'
require 'json'
require 'date'

## This module will show how many issues/pull requests have been closed by a
## user today. Plugin heavily based on
## https://gist.github.com/wadewilliams/f6e5e0354c3fb61fb910

## GitHub config stuff
github_token = ENV['GITHUB_TOKEN']
base_url = 'https://api.github.com/'
github_login_url = "#{base_url}user?access_token=#{github_token}"
github_login_response = JSON.parse RestClient.get github_login_url
github_login = github_login_response['login']


## Create the event name for Dashing
event_name = "git_issues_closed_by_user"

## Create an array to hold our data points
points = []

## Seed empty points (rickshaw acts funny if you don't).
(0..7).each do |a|
  points << { x: a, y: 0.01 }
end

SCHEDULER.every '5m', first_in: 0 do |job|
  now = DateTime.now
  midnight = DateTime.new(now.year, now.month, now.day)
  puts "#{Time.now} Getting closed issues from GitHub"

  ## Get the total number of issue pages we need to sort through
  watched_issues_response = []
  page_number = 1
  uri = "#{base_url}issues?access_token=#{github_token}&since="\
        "#{Time.iso8601(midnight.to_s)}&state=closed&filter=subscribed&"\
        "per_page=100&page=#{page_number}"
  last_page = 1
  if RestClient.head(uri).headers[:link]
    page_links = RestClient.head(uri).headers[:link].split(',').last.match('&page=\d+>;').to_s
    last_page = page_links[page_links.index('=')+1..page_links.index('>;')-1].to_i
  end

  ## Search through each issue and check if it was closed by us
  total_issues_closed_by_user = 0
  last_page.times do
    puts "#{Time.now} Grabbing page \##{page_number} of #{last_page} GitHub "\
         "issue page(s)"

    uri = "#{base_url}issues?access_token=#{github_token}&since="\
          "#{Time.iso8601(midnight.to_s)}&state=closed&filter=subscribed"\
          "&per_page=100&page=#{page_number}"
    response = JSON.parse RestClient.get uri
    for issue in response
      issue_json = JSON.parse RestClient.get "#{issue['url']}?access_token="\
                                             "#{github_token}"
      closed_by = issue_json['closed_by']
      closed_at = DateTime.parse(issue_json['closed_at'])
      if closed_by && closed_by['login'] == github_login && closed_at > midnight
        total_issues_closed_by_user += 1
      end
    end
    page_number += 1
  end

  puts "#{Time.now} GitHub-issues has just counted "\
       "#{total_issues_closed_by_user} closed issue(s)"

  ## Drop the first point value and increment x by 1
  points.shift
  last_x = points.last[:x] + 1

  ## Push the most recent point value
  points << {x: last_x, y: total_issues_closed_by_user}
  send_event(event_name, {text: total_issues_closed_by_user, points: points})

end # SCHEDULER
