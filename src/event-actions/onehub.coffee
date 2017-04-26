#! /usr/bin/env coffee

github = require('githubot')

onehub = {
  production_pull_request: (repo) ->
    github.get("repos/onehub/#{repo}/pulls",
      { state: "open", head: "staging", base: "master" },
      (pulls) ->
        switch pulls.length
          when 0
            return null
          when 1
            console.log pulls[0]
            return {
              id: pulls[0].id,
              body: pulls[0].body,
              number: pulls[0].number
            }
          else
            throw new Error('PullRequestQuantityError')
    )

  production_pull_request_commits: (repo) ->
    github.get("repos/onehub/#{repo}/pulls",
      { state: "open", head: "staging", base: "master" },
      (pulls) ->
        switch pulls.length
          when 0
            return null
          when 1
            github.get(
              "repos/onehub/#{repo}/pulls/#{pulls[0].number}/commits",
              { base: "master", head: "staging" },
              (res) ->
                console.log(res)
            )
          else
            throw new Error('PullRequestQuantityError')
    )


  create_pull_request: (repo) ->
    github.post("repos/onehub/#{repo}/pulls",
      { base: "master", head: "staging" },
      (res) ->
        console.log(res)
    )
}




module.exports = onehub


