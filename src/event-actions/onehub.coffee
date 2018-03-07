#! /usr/bin/env coffee

github = require('githubot')

onehub = {
  pull_request: (repo) ->
    new Promise (resolve, reject) ->
      github.get "repos/onehub/#{repo}/pulls",
        { state: "open", head: "staging", base: "master" },
        (pulls) ->
          deployPulls = pulls.filter((pull) -> pull.title.startsWith('Production Deploy'))

          switch deployPulls.length
            when 0
              resolve null
            when 1
              resolve {
                id: deployPulls[0].id,
                body: deployPulls[0].body,
                number: deployPulls[0].number
              }
            else
              throw new Error 'PullRequestQuantityError'

  # Until we support pagination we only get the first 250 commits
  pull_request_commits: (repo) ->
    self = this
    new Promise (resolve, reject) ->
      try
        self.pull_request(repo).then (pull_request) ->
          return null unless pull_request
          github.get "repos/onehub/#{repo}/pulls/#{pull_request.number}/commits?per_page=250", (commits) ->
            commit_msgs = (commit_msg.commit.message for commit_msg in commits)
            resolve commit_msgs
      catch e
        console.error "too manny problems", e

  commit_msgs: (repo) ->
    self = this
    new Promise (resolve, reject) ->
      self.pull_request_commits(repo).then (commit_msgs) ->
        resolve commit_msgs


  branches_to_merge: (repo) ->
    branch_pattern = /onehub\/(\d+.+)\\/
    branches = []
    self = this

    new Promise (resolve, reject) ->
      self.commit_msgs(repo).then((commit_msgs) ->
        for commit_msg in commit_msgs
          match = commit_msg.match(/onehub\/(\d+.+?)\n/)
          branches.push "##{match[1].replace(/\-/g, ' ')}" if match

        resolve branches
      )

  create_pull_request: (repo) ->
    self = this
    date = new Date()

    new Promise (resolve, reject) ->
      github.post "repos/onehub/#{repo}/pulls",
        {
          base: "master",
          head: "staging",
          title: self.pull_request_title(),
          body: "*AUTOMAGICALLY GENERATED DO NOT EDIT*\n\n",
        },
        (pull_request) ->
          github.put "repos/onehub/#{repo}/issues/#{pull_request.number}/labels", ['ready'], () ->
            resolve { url: pull_request.html_url, number: pull_request.number }

  pull_request_body: (pull_request_body, merge_data) ->
    data = [pull_request_body, "##{merge_data.pull_request.number} - #{merge_data.pull_request.title}"]

    data.filter((entry) -> !!entry).join("\n")

  pull_request_title: (pull_request_body) ->
    merge_count = if pull_request_body then pull_request_body.match(/(\#\d+)/g).length else 1

    items_text = if merge_count == 1 then 'Item' else 'Items'

    date_string = new Date().toLocaleDateString("en-US", { timeZone: 'America/Los_Angeles', month: 'numeric', day: 'numeric' })

    "Production Deploy - #{date_string} - #{merge_count} #{items_text}"

  update_pull_request: (repo, pull_request, merge_data) ->
    self = this
    body = @pull_request_body(pull_request.body, merge_data)
    title = @pull_request_title(body)

    new Promise (resolve, reject) ->
      github.patch "repos/onehub/#{repo}/pulls/#{pull_request.number}",
        {
          body: body
          title: title
        },
        (pull_request) ->
          resolve { url: pull_request.html_url, number: pull_request.number }

  create_or_update_pull_request: (merge_data) ->
    self = this
    repo = merge_data.repository.name

    new Promise (resolve, reject) ->
      self.pull_request(repo).then (pull_request) ->
        if pull_request
          self.update_pull_request(repo, pull_request, merge_data).then (pull_request) ->
            resolve pull_request
        else
          self.create_pull_request(repo).then (pull_request) ->
            self.update_pull_request(repo, pull_request, merge_data).then (pull_request) ->
              resolve pull_request
}

module.exports = onehub
