# frozen_string_literal: true

require 'date'
require 'time'
require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers(phone)
  phone = phone.delete('^0-9')
  if phone.length > 11 || phone.length < 10 || (phone.length == 11 && phone[0] != '1')
    'Bad phone number'
  elsif phone.length == 11
    phone.slice(1, 10)
  else
    phone
  end
end

def registration_hour(time)
  Time.strptime(time.to_s, '%D %R').hour
end

def registration_day(date)
  Date.strptime(date.to_s, '%D').wday
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
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

registrations_by_hour = Hash.new(0)
registrations_by_day = Hash.new(0)

contents.each do |row|
  id = row[0]
  registered_hour = registration_hour(row[:regdate])
  registrations_by_hour["Hour #{registered_hour}"] += 1
  registered_day = registration_day(row[:regdate])
  registrations_by_day["Day #{registered_day}"] += 1
  name = row[:first_name]
  home_phone = clean_phone_numbers(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

puts registrations_by_hour.sort_by { |_hour, registrations| registrations }.reverse.to_h
puts registrations_by_day.sort_by { |_day, registrations| registrations }.reverse.to_h
