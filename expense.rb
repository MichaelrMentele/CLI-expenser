#! /usr/bin/env ruby
require "pg"
require "io/console"
require "./models"

CLI.new.run(ARGV)