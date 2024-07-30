require_relative 'scraper_sitemap'

RSpec.describe ScraperSitemap do
  let(:scraper) { ScraperSitemap.new }
  let(:valid_url) { 'https://www.autocentrum.pl/dane-techniczne/abarth/500/ii/hatchback/silnik-elektryczny-elektryczny-42kwh-155km-od-2023/' }
  let(:invalid_url) { 'invalid-url' }
  let(:filename) {'ttest_links.csv'}

  describe '#split_url' do
    it 'correctly splits the URL' do
      url = 'https://www.autocentrum.pl/dane-techniczne/ford-focus/1.0-ecoboost-125hp'
      result = @scraper.split_url(url)
      expect(result).to eq(['ford focus', '1.0 ecoboost 125hp'])
    end

    it 'handles errors' do
      allow(@scraper).to receive(:split_url).and_raise(StandardError, 'Test error')
      expect { @scraper.split_url('url') }.not_to raise_error
    end
  end
end
