# gitlabira

Automate your Gitlab and Jira workflow

## Installation

* Setup sentry project at https://sentry.io
* You will need Jira account with password
* You will need Jira admin permission to view Jira workflow setting and get transition id

## Usage

* Make sure you fill all environment variables listed on `.env.sample`
* Start your server by `crystal run src/gitlabira.cr`

## Development

* Refer to [this article](https://devcenter.heroku.com/articles/git)
* Make sure you already create Gitlab integration for your project with `Push events` and `Merge request events` at https://docs.gitlab.com/ee/user/project/integrations/webhooks.html#ssl-verification

## Contributing

1. Fork it (<https://github.com/nnluukhtn/gitlabira/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Luu Nguyen](https://github.com/nnluukhtn) - creator and maintainer
