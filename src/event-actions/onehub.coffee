#! /usr/bin/env coffee

github = require('githubot')

module.exports =

  pull_requests: (repo) ->
    github.get("repos/onehub/#{repo}/pulls",
      { state: "open", head: "staging", base: "master" },
      (pulls) ->
        console.log(pulls)

        switch pulls.length
          when 0
            return null
          when 1
            pulls[0].id
          else
            throw new Error('PullRequestQuantityError')
    )

  create_pull_request: (repo) ->
    github.post("repos/onehub/#{repo}/pulls",
      { title: "Production", body: "Great", base: "master", head: "staging" }
    )
