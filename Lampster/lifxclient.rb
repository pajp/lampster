#!/usr/bin/env ruby

require 'lifx'
require 'json'
STDOUT.sync = true

puts "Hello."
@client = LIFX::Client.lan

def toggle_all(state)
    on = state
    toggle_count = 0
    @client.lights.lights.each { |light|
        if on
            light.turn_on!
        else
            light.turn_off!
        end
        toggle_count += 1
        puts ": #{JSON.generate({:toggle_count => toggle_count})}"
    }
    puts "OK"
end

puts "Discovering"
start_t = Time.new.to_i
last_t = start_t
last_bulb_count = 0
@client.discover! { |c|
    if c.lights.count > last_bulb_count
        last_t = Time.new.to_i
        puts "Bulbs found: #{c.lights.count} #{last_t}"
        puts ": #{JSON.generate({:bulb_count => c.lights.count})}"
    end
    last_bulb_count = c.lights.count
    Time.new.to_i - last_t > 3
}
scan_time = Time.new.to_i - start_t
if @client.lights.count == 0
    STDERR.puts "No lights found, giving up after #{scan_time} seconds."
    exit 1
else
    puts "#{@client.lights.count} bulbs found (searched for #{scan_time} seconds)."
    data = {:bulb_count => @client.lights.count, :scan_time => scan_time}
    puts ": #{JSON.generate(data)}"
end
puts "Ready."

#on = ARGV[0] == "on" ? true : false;

ARGF.each do |line|
    puts "ACK #{line}"
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


