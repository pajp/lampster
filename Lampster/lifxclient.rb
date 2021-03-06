#!/usr/bin/env ruby

require 'lifx'
require 'json'
STDOUT.sync = true

@SELECTED_TAG = "Selected in Lampster"

bulbcount = 0;
if ARGV.length > 0
  bulbcount = ARGV.shift.to_i
end
puts "Expecting #{bulbcount} bulbs"

puts "Hello."
@client = LIFX::Client.lan
LIFX::Config.message_wait_timeout = 5

@selected_bulbs = []
def toggle_all(state)
    toggle_one(nil, state)
    puts ": #{JSON.generate({:toggle_count => @client.lights.count})}"
end

def toggle_one(lampid, state)
    @client.lights.lights.each { |light|
        puts "Light #{light.id}"
        if light.id == lampid || lampid == nil
            if state
                puts "Turning on #{light.id}"
                light.turn_on!
            else
                puts "Turning off #{light.id}"
                light.turn_off!
            end
        end
    }
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
    # five seconds
    Time.new.to_i - last_t > 5 || (bulbcount > 0 && last_bulb_count == bulbcount)
}
scan_time = Time.new.to_i - start_t
if bulbcount > 0 && last_bulb_count < bulbcount
    STDERR.puts "Only found #{last_bulb_count} out of #{bulbcount} bulbs after #{scan_time} seconds."
    exit 1
end
if @client.lights.count == 0
    STDERR.puts "No lights found, giving up after #{scan_time} seconds."
    exit 1
else
    puts "#{@client.lights.count} bulbs found (searched for #{scan_time} seconds)."
    lightdata = {}
    @client.lights.lights.each { | light|
        lightdata[light.id] = { :id => light.id, :label => light.label }
        light.remove_tag @SELECTED_TAG
    }
    @client.purge_unused_tags!
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
        next
    end
    if /^light-set *(?<lampid>[0-9a-f]+) *(?<state>[01]{1})$/ =~ line
        toggle_one(lampid, state == "1")
        puts "OK"
    end
    if line =~ /^lights-on$/
        toggle_all(true)
        puts "OK"
        next
    end
    if line =~ /^lights-off$/
        toggle_all(false)
        puts "OK"
        next
    end
    if /^set-color *(?<hue>[0-9.]*) (?<saturation>[0-9.]*) (?<brightness>[0-9.]*)$/ =~ line
        puts "Received Hue #{hue} Saturation #{saturation} Brightness #{brightness}"
        @client.lights.set_color(LIFX::Color::hsb(hue.to_f, saturation.to_f, brightness.to_f))
        puts "OK"
        next
    end
    if /^sine *(?<hue>[0-9.]*) (?<saturation>[0-9.]*) (?<brightness>[0-9.]*)$/ =~ line
        puts "Sine Hue #{hue} Saturation #{saturation} Brightness #{brightness}"
        @client.lights.sine(LIFX::Color::hsb(hue.to_f, saturation.to_f, brightness.to_f))
        puts "OK"
        next
    end
    if /^set-color *(?<hue>[0-9.]*) (?<saturation>[0-9.]*) (?<brightness>[0-9.]*) (?<kelvin>[0-9]*) (?<duration>[0-9]*)$/ =~ line
        puts "Received Hue #{hue} Saturation #{saturation} Brightness #{brightness} Kelvin #{kelvin} Duration #{duration}"
        @client.lights.set_color(LIFX::Color::hsbk(hue.to_f, saturation.to_f, brightness.to_f, kelvin), duration: duration.to_f)
        puts "OK"
        next
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
        next
    end

    if /^set-color *(?<bulbid>[0-9a-f*]+) *(?<hue>[0-9.]*) (?<saturation>[0-9.]*) (?<brightness>[0-9.]*)$/ =~ line
        @client.lights.each do | light |
            if bulbid == "*" || light.id == bulbid
              light.set_color(LIFX::Color::hsb(hue.to_f, saturation.to_f, brightness.to_f))
              puts "For bulb #{bulbid} Hue #{hue} Saturation #{saturation} Brightness #{brightness}"
            end
        end
        puts "OK"
        next
    end

    if line =~ /^ping$/
        puts "OK"
        next
    end
    if line =~ /^exit$/
        puts "OK"
        puts "EOF"
        exit
    end
end
puts "EOF"


