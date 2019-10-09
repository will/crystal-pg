# Contributing

Make sure the change is properly tested and the build passes.
Submit a PR.
Thanks!

## Development requirements

- Crystal
- PostgreSQL server

You may also look into `.circleci/config.yml` and related `steps:` section to see
the configuration for the automated test suite.

### PostgreSQL Server setup

On macOS, using Homebrew, install and start the server.
You do not need to perform any configuration.

```shell
brew update
brew install postgresql
brew services start postgresql
```

### Running tests

1. Clone the repo to your computer, change directory to the cloned path
2. In the cloned repository, execute `shards install`
3. Run `crystal spec`

If all is well, you should see output containing `... 0 failures, 0 errors ...`
