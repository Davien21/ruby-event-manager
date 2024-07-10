# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number.gsub!(/\D/, '')
  phone_arr = phone_number.split('')

  phone_arr = phone_arr.slice(1..phone_arr.length) if phone_arr.length == 11 && phone_arr.first == '1'

  return "Bad number #{phone_number}" if phone_arr.length < 10
  return "Bad number #{phone_number}" if phone_arr.length >= 11

  phone_arr.join('')
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(row)
  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new template_letter

  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') { |file| file.puts form_letter }
end

def get_hourly_reg(table)
  table.sort { |a, b| b[1] - a[1] }.to_h
end

def handle_table_row(row, hours)
  homephone = row[:homephone]
  puts clean_phone_number(homephone)

  hour = Time.strptime(row[:regdate], '%m/%d/%y %H:%M').hour
  hours[hour] = hours[hour] + 1

  save_thank_you_letter(row)
end

def handle_event
  puts "EventManager initialized.\n\n"

  contents = CSV.open(
    'event_attendees.csv',
    headers: true,
    header_converters: :symbol
  )

  hours = Hash.new(0)

  contents.each { |row| handle_table_row(row, hours) }

  hour_table = hours.sort { |a, b| b[1] - a[1] }.to_h
  puts "\nHours table\n", hour_table
end

handle_event
