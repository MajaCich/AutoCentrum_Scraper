require './scraper'

# Creates a new instance of the Scraper class.
scraper = Scraper.new

# Scrapes car data from multiple links.
#
# @return [Array<Hash>] an array of hashes containing car data.
start_time = Time.now
cars = scraper.scrape_data_parallel

# Display additional info about scraping
end_time = Time.now
elapsed_time = end_time - start_time
puts "Czas wykonania (scrapowania): #{elapsed_time} sekund"
puts "Ilość aut: #{cars.length()}"

# Saves the scraped car data to a CSV file.
#
# @param cars [Array<Hash>] an array of hashes containing car data.
start_time = Time.now

# Sort cars by link
cars = cars.sort_by { |hash| hash['Link'] if hash.is_a?(Hash) }
scraper.save_to_csv(cars)
end_time = Time.now
elapsed_time = end_time - start_time
puts "Czas wykonania (zapisywania): #{elapsed_time} sekund"

# index 0 -> 25
#index 1 -> 412
# 0 .. 5 -> 2064
# 0 .. 10  -> 4791

