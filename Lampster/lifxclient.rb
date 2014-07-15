#!/usr/bin/env ruby

require 'lifx'
STDOUT.sync = true

puts "Hello."
@client = LIFX::Client.lan

def toggle_all(state)
    on = state
    
    @client.lights.lights.each { |light|
        if on
            light.turn_on!
        else
            light.turn_off!
        end
    }
    puts "OK"
end

puts "Discovering"
@client.discover! { |c| c.lights.count >= 2 }
puts "Ready."

#on = ARGV[0] == "on" ? true : false;

ARGF.each do |line|
    puts "Read a line #{line}"
    if line =~ /^lights-on$/
        toggle_all(true)
    end
    if line =~ /^lights-off$/
        toggle_all(false)
    end
    if line =~ /^ping$/
        puts "OK"
    end
    if line =~ /^exit$/
        puts "OK"
    end
end
puts "EOF"


