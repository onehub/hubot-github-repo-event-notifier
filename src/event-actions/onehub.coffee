#! /usr/bin/env coffee

github = require('githubot')

PULL_REQUEST_BODY = "AUTOMATICALLY GENERATED DO NOT EDIT\n\n"

onehub = {
  pull_request: (repo) ->
    new Promise (resolve, reject) ->
      github.get "repos/onehub/#{repo}/pulls",
        { state: "open", head: "staging", base: "master" },
        (pulls) ->
          switch pulls.length
            when 0
              resolve null
            when 1
              resolve {
                id: pulls[0].id,
                body: pulls[0].body,
                number: pulls[0].number
              }
            else
              throw new Error 'PullRequestQuantityError'

  pull_request_commits: (repo) ->
    self = this
    new Promise (resolve, reject) ->
      try
        self.pull_request(repo).then (pull_request) ->
          return null unless pull_request
          github.get "repos/onehub/#{repo}/pulls/#{pull_request.number}/commits", (commits) ->
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

    new Promise (resolve, reject) ->
      github.post "repos/onehub/#{repo}/pulls",
        { base: "master", head: "staging", title: "Production" },
        (pull_request) ->
          resolve { url: pull_request.html_url, number: pull_request.number }

  update_pull_request: (repo, number) ->
    self = this

    new Promise (resolve, reject) ->
      self.branches_to_merge(repo).then (branches) ->
        github.patch "repos/onehub/#{repo}/pulls/#{number}",
          { body: "#{PULL_REQUEST_BODY} #{branches.join('\n')}" },
          (pull_request) ->
            resolve { url: pull_request.html_url, number: pull_request.number }

  create_or_update_pull_request: (repo) ->
    self = this

    console.log("REPO NAME: ", repo)

    new Promise (resolve, reject) ->
      self.pull_request(repo).then (pull_request) ->
        if pull_request
          self.update_pull_request(repo, pull_request.number).then (pull_request) ->
            resolve pull_request
        else
          self.create_pull_request(repo).then (pull_request) ->
            self.update_pull_request(repo, pull_request.number).then (pull_request) ->
              resolve pull_request
}

module.exports = onehub
