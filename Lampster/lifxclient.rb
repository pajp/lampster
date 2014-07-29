#!/usr/bin/env ruby

require 'lifx'
require 'json'
STDOUT.sync = true

@SELECTED_TAG = "Selected in Lampster"


puts "Hello."
@client = LIFX::Client.lan
@selected_bulbs = []
def toggle_all(state)
    if state
        @client.lights.turn_on
    else
        @client.lights.turn_off
    end
    puts ": #{JSON.generate({:toggle_count => @client.lights.count})}"
    puts "OK"
end

def toggle_selected(state)
    on = state
    toggle_count = 0
    @client.lights.lights.each { |light|
        puts "Light: #{light.id}"
        bulb_is_selected = false
        @selected_bulbs.each { |id|
            if light.id == id
                bulb_is_selected = true
            end
        }
        if bulb_is_selected
            if on
                light.turn_on!
                else
                light.turn_off!
            end
            toggle_count += 1
            puts ": #{JSON.generate({:toggle_count => toggle_count})}"
        end
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
    # stop looking if no new bulb has announced itself during the last
    # three seconds
    Time.new.to_i - last_t > 3
}
scan_time = Time.new.to_i - start_t
if @client.lights.count == 0
    STDERR.puts "No lights found, giving up after #{scan_time} seconds."
    exit 1
else
    puts "#{@client.lights.count} bulbs found (searched for #{scan_time} seconds)."
    lightdata = {}
    @client.lights.lights.each { | light|
        lightdata[light.id] = { :id => light.id, :label => light.label }
        @selected_bulbs.push light.id
        light.add_tag @SELECTED_TAG
    }
    data = {:bulb_count => @client.lights.count, :scan_time => scan_time, :lights => lightdata }
    puts ": #{JSON.generate(data)}"
end
puts "Ready."

#on = ARGV[0] == "on" ? true : false;


ARGF.each do |line|
    puts "ACK #{line}"
    if /^select-bulbs *(?<bulbids>[0-9a-f ]*)$/ =~ line
        puts "Bulb IDs selected: \"#{bulbids}\""
        @selected_bulbs = bulbids.split " "
        @client.lights.each do | light |
            if @selected_bulbs.include? light.id
                light.add_tag @SELECTED_TAG
            else
                light.remove_tag @SELECTED_TAG
            end
        end
        puts "OK"
    end
    if line =~ /^lights-on$/
        if @selected_bulbs.count == @client.lights.count
            toggle_all(true)
        else
            toggle_selected(true)
        end
    end
    if line =~ /^lights-off$/
        if @selected_bulbs.count == @client.lights.count
            toggle_all(false)
        else
            toggle_selected(false)
        end
    end
    if /^set-color *(?<hue>[0-9.]*) (?<saturation>[0-9.]*) (?<brightness>[0-9.]*)$/ =~ line
        puts "Received Hue #{hue} Saturation #{saturation} Brightness #{brightness}"
        @client.lights.with_tag(@SELECTED_TAG).set_color(LIFX::Color::hsb(hue.to_f, saturation.to_f, brightness.to_f))
        puts "OK"
    end
    if line =~ /^lights-status$/
        @client.refresh # note: refresh is asynchronous so light status may not
        lights = []     # be immediately visible
        @client.lights.each do | light |
            color = light.color
            lights.push({ "id" => light.id, "power" => light.power,
                          "hue" => color.hue, "saturation" => color.saturation,
                          "brightness" => color.brightness,
                          "kelvin" => color.kelvin })
        end
        data = { "lights-status" => lights }
        puts ": #{JSON.generate(data)}"
        puts "OK"
    end
    if line =~ /^ping$/
        puts "OK"
    end
    if line =~ /^exit$/
        puts "OK"
    end
end
puts "EOF"


