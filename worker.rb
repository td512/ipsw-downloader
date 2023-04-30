require 'json'
require 'yaml'
require 'net/http'
require 'fileutils'

# Created October 2019 by Theo M. <theo@theom.nz>
# The license can be found as `LICENSE`

# Check if the file exists, if not set up the workload
if File.file?('devices.yml') && File.file?('firmwares.yml')
  device_identifiers = YAML.load_file('devices.yml')
  device_firmwares   = YAML.load_file('firmwares.yml')
else 
  # Download a list of all Apple devices
  uri = URI('https://api.ipsw.me/v4/devices')
  response = Net::HTTP.get_response(uri)

  # Build a hash with both the device name, and identifier
  # ------------------------------------------------------
  # Parse the response
  json = JSON.parse(response.body)

  # Set up the arrays
  device_identifiers = Hash.new

  # We now need to map everything out. This part is easy
  json.each do |item|
    device_identifiers[item["name"].gsub('/', '-')] = item["identifier"]
  end

  # We now have our hash. We now need to fetch a list of all firmwares for all devices. 
  # This part could take a little bit. After this, we'll save our working set. We don't want to poll the API every 5 seconds
  # ------------------------------------------------------------------------------------------------------------------------
  # Set up the hash...
  device_firmwares = Hash.new

  # You get the idea...
  device_identifiers.each do |device, ident|
    # For each device we need to poll the IPSW.me API
    puts "Processing #{device} as #{ident}"
    uri = URI("https://api.ipsw.me/v4/device/#{ident}?type=ipsw")
    response = Net::HTTP.get_response(uri)
  
    # This returns a list of firmwares, as well as a list of all firmwares, valid or not
    # Let's loop through them, and build a list of URLs
    json = JSON.parse(response.body)
    json["firmwares"].each do |item|
      if device_firmwares.key?(item["identifier"])
        if device_firmwares.keys.last == item["identifier"]
          device_firmwares[item["identifier"]] = device_firmwares[item["identifier"]] + "#{item["url"]}|"
        else
          device_firmwares[item["identifier"]] = device_firmwares[item["identifier"]] + "|#{item["url"]}"
        end
      else
        device_firmwares[item["identifier"]] = "#{item["url"]}|" unless item["identifier"] == "iPhone1,1" 
        device_firmwares[item["identifier"]] = "#{item["url"]}|" if item["identifier"] == "iPhone1,1"
      end
    end
  end
  # Looks like we've got all we need. Let's dump it to file. This is important as to not overload IPSW.me's API
  File.open('devices.yml', 'w') { |f| f.write(device_identifiers.to_yaml) } 
  File.open('firmwares.yml', 'w') { |f| f.write(device_firmwares.to_yaml) }
end

# Loop through the devices and set up the directory hierarchy
device_identifiers.each do |device, identifier|
  FileUtils.mkdir_p("output/#{device}")
end

# Build a list for aria2
file = File.open('ipsw_list', 'w') 
device_firmwares.each do |identifier, firmware|
  device = device_identifiers.key(identifier)
  #file.puts(firmware)
  file.puts(firmware.gsub('|', "\n dir=output/#{device}\n"))
end
file.close
puts "Compilation complete! Run aria2c -x16 -s16 --input-file ipsw_list"
