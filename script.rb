require './scraper'
require './scraper_sitemap'

scraper = ScraperSitemap.new

start_time = Time.now
cars = scraper.scrape_data_sitemap_parallel

end_time = Time.now
time = end_time - start_time

# Display additional info
puts "Czas wykonania (scrapowania): #{time} sekund"
puts "Ilość aut: #{cars.length()}"

# Sort by links
cars = cars.compact.sort_by { |hash| hash['Link'] if hash.is_a?(Hash) }

# Save data (append to existing data)
scraper.append_and_save_to_csv(cars)

# index 0 -> 25
# index 1 -> 412
# 0 .. 5 -> 2064
# 0 .. 10  -> 4803
# 11 .. 20 -> 5245
# 21 .. 30 -> 4893
# 31 .. 40 -> 6464
# Wszystkie: 29490
