# The purpose of the tool is automate the testing of the metrics for web pages and send the results to desired recipeient. 

require 'selenium-webdriver'
require 'mail'

@wait = Selenium::WebDriver::Wait.new(:timeout => 15)
@runner_site = "https://www.webpagetest.org"
@debug = false

def spin_up_webdriver
  @driver = Selenium::WebDriver.for :chrome
end

def close_down_webdriver
  @driver.close
end

def load_links(text_file_name)
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
    if @debug
        safe_url_file_name = safe_url_name(url)+".png"
        @driver.save_screenshot "before_"+safe_url_file_name
    end
    input = @wait.until {
        element = @driver.find_element(:id, "url")
        element if element.displayed?
        }
    input.send_keys(url)
    input.click
    input.send_keys(:enter)
    result_link = @driver.current_url
    # xml_result = @driver.current_url.sub("/result/","/xmlResult/")
    if @debug
        @driver.save_screenshot "after_"+safe_url_file_name
        puts result_link
        puts safe_url_file_name
    end
    return [result_link,url]
end

def get_the_results(result_url,url)
    @driver.navigate.to result_url
    if @debug
        wait_time(1)
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

def main(link_list)
    # Load links to test.
    urls = load_links(link_list)
    spin_up_webdriver
    # Create an empty array to store the result link.
    result_urls = []
    # itterate through the links, and collect the result links
    urls.each do |url|
        # Test the link and return the xml link of the result.
        result_urls << test_url_metrics(@runner_site,url)
    end
    # wait for 30 secs
    if @debug
        wait_time(30)
    end
    results_stats = []
    result_urls.each do |result_url,url|
        # Test the link and return the xml link of the result.
        results_stats << get_the_results(result_url,url)
    end
    # Output the results to a text file
    IO.write("stats.txt", results_stats.join("\n"))

    close_down_webdriver

end

def safe_url_name(url)
  url.gsub(/[\W]+/, '_')
end

#checks for a file named links.txt and executes if it exists
if File.exist?("links.txt")
  main("links.txt")
end


#mail section - to be refactored.
options = { :address              => "smtp.gmail.com",
            :port                 => 587,
            :domain               => 'localhost',
            :user_name            => 'example@gmail.com',
            :password             => 'password',
            :authentication       => 'plain',
            :enable_starttls_auto => true  }

Mail.defaults do
  delivery_method :smtp, options
end

Mail.deliver do
    from     'example@gmail.com'
    to       'testexample@example.com'
    subject  "subject text" 
    body     File.read('stats.txt')
end