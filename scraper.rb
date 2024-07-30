require 'httparty' 
require 'nokogiri'
require 'logger'
require 'csv'
require 'thread'

# Class that scraps data from autocentrum.pl
# Data =  cars information
class Scraper
  # @!attribute [r] header
  # @return [Hash] the headers used for HTTP requests, typically including a User-Agent string.
  attr_reader :header

  # @!attribute [r] base_link
  # @return [String] the base URL for the website being scraped.
  attr_reader :base_link

  # Initializes a new Scraper instance. Also create logger instance for loggs
  #
  def initialize
    @header = { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36" }
    @base_link = 'https://www.autocentrum.pl'
    @logger = Logger.new('./logs/scraper.log')
    @logger.level = Logger::DEBUG
  end

  # Split url and cut unnecessary data
  #
  # @param url [String] The url to split
  # @return [String] The changed url
  def split_url(url)
    base_url = self.base_link + '/dane-techniczne/'
    stripped_url = url.sub(base_url, '')
  
    parts = stripped_url.split('/')
    parts.reject!(&:empty?)
    parts.map! { |part| part.gsub('-', ' ') }
  
    return parts
  end

  # Fetches data from the given link, retrying up to 3 times in case of failure.
  #
  # @param link [String] The relative link to append to the base URL for the HTTP request.
  # @return [HTTParty::Response] The response object from the HTTP request if successful.
  # @raise [RuntimeError] If the HTTP request fails after 3 attempts.
  def fetch_data(link)
    max_retries = 3
    attempts = 0

    begin
      response = HTTParty.get( link, {
        headers: self.header,
      })

      if response.code != 200
        raise "HTTP request failed with code #{response.code}"
      end

      return response.body
    rescue => e
      attempts += 1
      @logger.error("Attempt #{attempts}: #{e.message} for URL #{link}")

      if attempts < max_retries
        @logger.info("Retrying...")
        sleep(2)  
        retry
      else
        @logger.error("All retry attempts failed for URL #{link}")
        raise "HTTP request failed after #{max_retries} attempts"
      end
    end
  end

  # Retrieves a list of all car brand links.
  #
  # @return [Array<String>] an array of URLs to brand pages.
  def read_all_brands()
    brands = []
    begin

      body = fetch_data(self.base_link+'/dane-techniczne/')

      document = Nokogiri::HTML(body)

      brand_class = ['popular-make','not-popular-make']

      brand_class.each do |class_name|
        a_elements = document.xpath("//div[contains(@class, 'make-wrapper') and contains(@class, '#{class_name}')]/a")
        a_elements.each { |a| brands.push(a.attr('href')) } 
      end
      @logger.info('All brands were successfully read')
      return brands
    rescue StandardError => e
      @logger.error("Error while scraping brands: #{e.message}")
    end
  end

  # Scrapes car data from multiple links. Use parallel processing.
  # Use threads to speed up scraping.
  #
  # @return [Array<Hash>] an array of hashes containing car data.
  def scrape_data_parallel
    mutex = Mutex.new
    cars = []
    threads = []
    i = 0 
    
    begin
      existing_links = load_existing_links('cars_data.csv')
      brands = read_all_brands()

      if brands.empty? || brands.nil? || !brands.is_a?(Array)
        @logger.error("Can not scrape data when brands data is empty/is nil/is not an array")
         raise "Invalid brands data"
      end

      brands = brands[0..1]
      models = []
    
      brands.each_with_index do |brand, index|
        models.concat(find_links(brand))
      end
    
      models.each do |model|
        threads << Thread.new do
        links_to_visit = find_links(model)

        if links_to_visit.nil? || links_to_visit.empty?
          if !existing_links.include?(self.base_link+model)
            car_data = scrape_car_data(model)
            mutex.synchronize do
              cars.push(car_data) 
            end
            mutex.synchronize { i+=1}
            puts i
            next
          end
        end
        
        while links_to_visit.any?
          link = nil
          mutex.synchronize { link = links_to_visit.pop }
          next unless link 
          begin 
            new_links = find_links(link) || []
      
            if new_links.empty? && !existing_links.include?(self.base_link+link)
              car_data = scrape_car_data(link)
              mutex.synchronize { cars.push(car_data) }
              mutex.synchronize { i+=1}
              puts i
            else
              mutex.synchronize { links_to_visit.concat(new_links) }
            end
          rescue StandardError => e
            @logger.error("Some error occur while finding links: #{new_links}")
          end
        end
      end
    end
      threads.each(&:join) 
      return cars
    rescue StandardError => e
      @logger.error("Error occurred while scraping data (parallel): #{e.message}")
      return []
    end
  end

  # Finds all possible model, version, engine type links for a given brand.
  #
  # @param link [String] the URL to search for links.
  # @return [Array<String>] an array of URLs found on the page.
  def find_links(link)
    begin 
      body = fetch_data(self.base_link+link)
    
      document = Nokogiri::HTML(body)
      a_elements = document.xpath("//div[contains(@class, 'car-selector-box-row')]/a")
      data = []
    
      if a_elements.nil? || a_elements.empty?
        cars_links = read_cars_from_engine_box(document)
        if cars_links.nil? || cars_links.empty?
          return []
        else
          return cars_links
        end
      end
    
      a_elements.each do |a|
        link = a.attribute('href').value
        data.push(link)
      end
      
      @logger.info("Success! New links were found.")
      return data
    rescue StandardError => e
      @logger.error("Error while scraping brands: #{e.message}")
    end
  end

  # Reads car links from the engine box section of a document.
  #
  # @param document [Nokogiri::HTML::Document] the Nokogiri HTML document to parse.
  # @return [Array<String>, nil] an array of car links or nil if no links are found.
  def read_cars_from_engine_box(document)
    a_elements = document.xpath("//div[contains(@class, 'engine-box')]/a")

    if a_elements.nil? || a_elements.empty?
      return []
    else
      cars = []
      a_elements.each do |a|
        car_link = a.attribute('href').value
        cars.push(car_link)
      end
      return cars
    end
  end

  # Scrapes data for a specific car.
  #
  # @param car_link [String] the URL of the car page to scrape.
  # @return [Hash] a hash containing the car data.
  def scrape_car_data(car_link)
    car = {}
    link = base_link + car_link

    begin
      body = fetch_data(link)

      document = Nokogiri::HTML(body)

      divs = document.xpath("//div[contains(concat(' ', @class, ' '), ' dt-row ') or contains(@class, 'dt-row no-value ')]")
      name = document.xpath("//div[contains(@class, 'info-wrapper')]/div[contains(@class, 'name')]").text.strip
      car['Pełna nazwa'] = name
      data_from_url = split_url(link)
      car['Marka'] = data_from_url[0]
      car['Model'] = data_from_url[1]
      car['Link'] = link

      divs.each do |div|
        d = div.xpath(".//div[contains(@class, 'dt-row__text__content')]")
        data_label_value = d.text

        classes = div.attr('class').split
        if classes.include?('no-value')
          car[data_label_value] = 'brak danych'
        else
          span = div.xpath(".//span[contains(@class, 'dt-param-value')]")
          car[data_label_value] = span.text.strip
        end
      end
      return car
    rescue StandardError => e
      @logger.error("Error while scraping car data: #{e.message}")
    end
  end

  # Displays car data in a readable format.
  #
  # @param car [Hash] the car data to display.
  def display_car_data(car)
    car.each { |name, value| puts name + ' : ' + value }
  end

  # Append car data to existing csv file
  #
  # @param cars [Array<Hash>] an array of hashes containing car data.
  def append_and_save_to_csv(cars)
    filename = 'cars_data.csv'
    csv_headers = []
  
    if cars.empty?
      @logger.warn('No data to save. Variable cars is empty')
      raise "No data to save"
      return
    end
  
    begin
      largest_hash = cars.max_by { |car| car.keys.size }
  
      largest_hash.each_key do |name|
        csv_headers.push(name)
      end
  
      file_exists = File.exist?(filename)
  
      CSV.open(filename, 'a+', write_headers: !file_exists, headers: csv_headers) do |csv|
        unless file_exists
          csv << csv_headers
        end
  
        cars.each do |car|
          row = csv_headers.map { |header| car[header] || '' }
          csv << row
        end
      end
      @logger.info("Data successfully saved to #{filename}")
    rescue StandardError => e
      @logger.error("Error while saving to CSV file: #{e.message}")
    end
  end

  # Saves car data to a CSV file.
  #
  # @param cars [Array<Hash>] an array of hashes containing car data.
  def save_to_csv(cars)
    filename = 'cars_data.csv'
    csv_headers = []

    if cars.empty?
      @logger.warn('No data to save. Variable cars is empty')
      raise "No data to save"
      return
    end

    begin
      largest_hash = cars.max_by { |car| car.keys.size }

      largest_hash.each_key do |name|
        csv_headers.push(name)
      end

      # Save the data to a CSV file.
      CSV.open(filename, 'wb', write_headers: true, headers: csv_headers) do |csv|
        cars.each do |car|
          row = csv_headers.map { |header| car[header] || '' }
          csv << row
        end
      end
      @logger.info("Data successfully saved to #{filename}")
    rescue StandardError => e
      @logger.error("Error while saving to csv file: #{e.message}")
    end
  end

  # Loads car data from a CSV file.
  #
  # @param filename [String] the name of the CSV file to load.
  # @return [Array<Hash>] an array of hashes, where each hash represents a car.
  def load_from_csv(filename)
    begin
      rows = []
      CSV.foreach(filename, encoding: 'UTF-8') do |row|
        rows << row.to_s.split(',')
      end
      @logger.info("Data successfully loaded from #{filename}")
      return rows
    rescue StandardError => e
      @logger.error("Error while loading from csv file: #{e.message}")
      return []
    end
  end
end


