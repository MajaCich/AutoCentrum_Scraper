require 'httparty' 
require 'nokogiri'
require 'logger'
require 'csv'
require 'thread'

# Class that scraps data from autocentrum.pl. Uses sitemap to find links
# Data =  cars information
class ScraperSitemap
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
    begin 
      base_url = self.base_link + '/dane-techniczne/'
      stripped_url = url.sub(base_url, '')
  
      parts = stripped_url.split('/')
      parts.reject!(&:empty?)
      parts.map! { |part| part.gsub('-', ' ') }
  
      return parts
    rescue StandardError => e
      @logger.error("Error while spliting url: #{e.message}")
    end
  end

  # Loads existing links from a CSV file.
  #
  # @param filename [String] the name of the CSV file to load.
  # @return [Array<String>] an array of links.
  def load_existing_links(filename)
    begin 
      existing_links = []
      CSV.foreach(filename, headers: true, encoding: 'UTF-8') do |row|
      existing_links << row['Link'] if row['Link']
      end
      @logger.info("Existing links successfully loaded from #{filename}")
      existing_links
    rescue
      @logger.error("Error while reading existing links from #{filename}")
    end
  end

  # Fetches links from the sitemap.
  #
  # @return [Array<String>] an array of links extracted from the sitemap.
  def links_from_sitemap()
    begin 
      link = 'https://www.autocentrum.pl/sitemap/daneTechniczne.xml'
      body = fetch_data(link)
      document = Nokogiri::HTML(body)
      loc_tags = document.xpath('//url/loc').map(&:text)
      return loc_tags
    rescue StandardError => e
      @logger.error("Error while reading links from sitemap link: #{e.message}")
    end 
  end

  # Scrapes data for a specific car.
  #
  # @param document [HTML_Document] html documant parsed by Nokogiri
  # @param link [String] the URL of the car page to scrape.
  # @return [Hash] a hash containing the car data.
  def scrape_car_data(document, link)
    car = {}

    begin
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

  # Scrapes car data. Takes links from sitemap. This function uses parallel processing
  #
  # @return [Array<Hash>] an array of hashes, where each hash represents a car.
  def scrape_data_sitemap_parallel
    cars = []
    links = links_from_sitemap
    existing_links = load_existing_links('cars_data.csv')
    links -= existing_links

    i = 0
    begin
      mutex = Mutex.new
      threads = []
      max_threads = 200

      links.each_slice((links.size / max_threads.to_f).ceil) do |link_batch|
      link_batch.each do |link|
        count = link.count('/')
        next if count <= 6

        threads << Thread.new do
          begin
            body = fetch_data(link)
            document = Nokogiri::HTML(body)
            a_elements = document.xpath("//div[contains(@class, 'car-selector-box-row')]/a")

            if a_elements.nil? || a_elements.empty?
              cars_links = read_cars_from_engine_box(document)
              if cars_links.nil? || cars_links.empty?
                index = links.index(link)
                other_link = links[index+1]

                if !other_link.include?(link)
                  car_data = scrape_car_data(document, link)
                  mutex.synchronize { cars.push(car_data) }
                  mutex.synchronize { i += 1 }
                  puts i    
                end    
              end
            end
          rescue StandardError => e
            @logger.error("Error while processing link #{link}: #{e.message}")
          end
        end
          if threads.size >= max_threads
            threads.each(&:join)
            threads.clear
          end
        end
      end
      threads.each(&:join)
      return cars
    rescue
      @logger.error("Error while scraping data link : #{e.message}")
    end
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

  # Load data from csv file then sorts it and saves it again to csv file. Sort by first column (fullname of car)
  #
  # @param filename [String] the filename of file from data is read
  # @return [void]
  def sort_csv_by_first_column(filename)
    csv_data = CSV.read(filename, headers: true, encoding: 'UTF-8')
    sorted_csv_data = csv_data.sort_by { |row| row[0] }
    CSV.open('sorted_data.csv', 'w', write_headers: true, headers: csv_data.headers, encoding: 'UTF-8') do |csv|
      sorted_csv_data.each do |row|
        csv << row
      end
    end
  end

end
