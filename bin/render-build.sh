#!/usr/bin/env bash

# Build rails for render.com
# From https://render.com/docs/deploy-rails-8

set -o errexit

bundle install
bin/rails assets:precompile
bin/rails assets:clean

bin/rails db:migrate
