# The purpose of the tool is automate the testing of the metrics for web pages and send the results to desired recipeient. 

require 'selenium-webdriver'
require 'mail'

@wait = Selenium::WebDriver::Wait.new(:timeout => 15)
@runner_site = "https://www.webpagetest.org"

def spin_up_webdriver
  @driver = Selenium::WebDriver.for :chrome
end

def close_down_webdriver
  @driver.close
end

# returns true if an exception is not thrown
def rescue_exceptions
    begin
      yield
    rescue Selenium::WebDriver::Error::NoSuchElementError
      return false
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      return false
    end
    return true
end
  
# Returns a boolean for the element exist method.
def elem_exist?(meth = {}, elem = {})
    rescue_exceptions { @driver.find_element(meth, elem)}
end

def parse_textfile_to_array(text_file_name)
    url_list_array = []
    input = File.open(text_file_name, 'r')
    while (line = input.gets)
      url_list_array << line.to_s.chomp
    end
    input.close
    url_list_array
end

def test_url_metrics(runner_site,url)
    @driver.navigate.to runner_site
    input = @wait.until {
        element = @driver.find_element(:id, "url")
        element if element.displayed?
        }
    input.send_keys(url)
    input.click
    input.send_keys(:enter)
    # Wait a sec for the current url to change.
    wait_time(1)
    result_link = @driver.current_url
    # xml_result = @driver.current_url.sub("/result/","/xmlResult/")
    return [result_link,url]
end

def get_the_results(result_url,url)
    puts "#{result_url} #{url} #{@driver}"
    @driver.navigate.to result_url
    # Check that the tests are done
    page_loaded = false
    timeouts = 0
    timeout_maxed = false
    # Keep checking if the page loaded.
    until (page_loaded or timeout_maxed)
        # check if the target element exists
        page_loaded = elem_exist?(:id, "LoadTime")   
        # Wait 2 secs before rechecking.
        if !page_loaded
            wait_time(2)
            timeouts = timeouts+1          
        end 
        # # If it's been longer than 3 min, give up and move onto the next url.
        if timeouts >= 90
            timeout_maxed = true
            return "Results took longer than 180 seconds to finish running."
        end
    end

    loadtime = @driver.find_element(:id, "LoadTime").text
    firstbyte = @driver.find_element(:id, "TTFB").text
    page_stats = url + "  " + "loadtime " +loadtime + "  " + "firstbyte "+ firstbyte
    puts page_stats
    return page_stats
end

def wait_time(t_minus)
    t = Time.new(0)
    countdown_time_in_seconds = t_minus

    countdown_time_in_seconds.downto(0) do |seconds|
        puts (t + seconds).strftime('%H:%M:%S')
        sleep 1
    end
end

def main(link_list,credential_file)
    #checks for the link_list file, and exits program with warning, if it doesn't exists
    unless File.exist?(link_list)
        puts "#{link_list} not found, please ensure that the #{link_list} path is correct."
        return
    end
    # Load links to test.
    urls = parse_textfile_to_array(link_list)
    # Power on Chrome Webdriver.
    spin_up_webdriver
    # Create an empty array to store the result links.
    result_urls = []
    # itterate through the links, and collect the result links
    urls.each do |url|
        # Test the link and return the xml link of the result.
        result_urls << test_url_metrics(@runner_site,url)
    end

    results_stats = []
    result_urls.each do |result_url,url|
        # Test the link and return the xml link of the result.
        results_stats << get_the_results(result_url,url)
    end
    # Output the results to a text file.
    IO.write("stats.txt", results_stats.join("\n"))
    # Shut down Web driver.
    close_down_webdriver

    # Mail report of the results.
    if File.exist?(credential_file)
        credentials = parse_textfile_to_array(credential_file)
        mail_the_report(credentials[0],credentials[1],credentials[2],credentials[3],credentials[4])
    else
        puts "Mailing report aborted! #{credential_file} not found, please ensure that the #{credential_file} path is correct."    
    end

end

def safe_url_name(url)
  url.gsub(/[\W]+/, '_')
end

def mail_the_report(sender,user_name,password,stat_file = "stats.txt",recipeient = sender)
    options = { :address              => "smtp.gmail.com",
                :port                 => 587,
                :domain               => 'localhost',
                :user_name            => user_name,
                :password             => password,
                :authentication       => 'plain',
                :enable_starttls_auto => true  }

    Mail.defaults do
    delivery_method :smtp, options
    end

    Mail.deliver do
        from     sender
        to       recipeient
        subject  "Web Metric Report" 
        body     File.read(stat_file)
    end
end

# Start the tool.
main("links.txt","credentials.txt")