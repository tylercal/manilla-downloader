require 'mechanize'
require 'fileutils'

def run
  download_directory = prompt('Directory to save documents', './downloads')
  email = prompt('Your Manilla email address')
  password = prompt('Password')

  FileUtils.makedirs(download_directory)

  agent = Mechanize.new
  agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  login_form = agent.get('https://app.manilla.com/users/sign_in').forms.first
  login_form['user[email]'] = email
  login_form['user[password]'] = password

  confirm_form = agent.submit(login_form).forms.first
  security_field = confirm_form.field_with(name: 'security_question')
  return puts 'There was a problem logging in. Please check your email and password.' unless security_field
  security_question = security_field.options[1]
  security_question.select
  confirm_form.security_answer = prompt(security_question)

  logged_in_page = agent.submit(confirm_form).link_with(href: '/documents')
  return puts 'There was a problem with your security answer.' unless logged_in_page
  docs_page = logged_in_page.click
  loop do
    download_page(agent, docs_page, download_directory)
    link = docs_page.link_with(text: 'NEXT')
    break unless link
    docs_page = link.click
  end
end

def download_page(agent, page, directory)
  rows = page.search('table > tbody > tr.doc')
  rows.each do |row|
    account = row.search('td > a.hidden-inline-xs').text.strip
    date = row.search('td.date').text.strip
    id = row.search('@data-doc-id').to_s
    file = "#{directory}/#{account} - #{date}.pdf"
    puts file
    agent.get("https://app.manilla.com/documents/#{id}/download").save(file)
  end
end

def prompt(name, default = nil)
  suffix = default.nil? ? '' : "[#{default}]"
  print("#{name}#{suffix}: ")
  value = gets.chomp
  value.empty? ? default : value
end

run