require './scraper_sitemap'

scraper = ScraperSitemap.new

scraper.sort_csv_by_first_column('cars_data.csv')

