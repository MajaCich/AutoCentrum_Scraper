# spec/scraper_spec.rb
require_relative '../scraper' 

RSpec.describe Scraper do
  let(:scraper) { Scraper.new }
  let(:valid_url) { 'https://www.autocentrum.pl/dane-techniczne/abarth/500/ii/hatchback/silnik-elektryczny-elektryczny-42kwh-155km-od-2023/' }
  let(:invalid_url) { 'invalid-url' }
  
  describe '#initialize' do
    it 'initializes with correct headers' do
      expect(scraper.header).to eq({ "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36" })
    end
  
    it 'initializes with correct base link' do
      expect(scraper.base_link).to eq('https://www.autocentrum.pl')
    end
  end
  
  describe '#split_url' do
    it 'splits and cleans the URL' do
      url = 'https://www.autocentrum.pl/dane-techniczne/marka/model/'
      result = scraper.split_url(url)
      expect(result).to eq(['marka', 'model'])
    end
  end

  describe '#read_all_brands' do
    before do
      fake_response = instance_double(HTTParty::Response, code: 200, body: '<html></html>')
      allow(HTTParty).to receive(:get).and_return(fake_response)
      fake_document = Nokogiri::HTML('<div><article></article></div>')
      allow(Nokogiri).to receive(:HTML).and_return(fake_document)
    end

    it 'returns an array of brand links' do
      brands = scraper.read_all_brands
      expect(brands).to be_an(Array)
      expect(brands.all? {|brand| brand.is_a?(String)}).to be true
    end
  end

  describe '#scrape_data' do
    before do
      fake_response = instance_double(HTTParty::Response, code: 200, body: '<html></html>')
      allow(HTTParty).to receive(:get).and_return(fake_response)
      fake_document = Nokogiri::HTML('<div><article></article></div>')
      allow(Nokogiri).to receive(:HTML).and_return(fake_document)
    end
    
    it 'returns an array of Car objects' do
      cars = scraper.scrape_data
      expect(cars).to be_an(Array)
      expect(cars.all? { |car| car.is_a?(Hash) }).to be true
    end
  end

  describe '#scrape_data_parallel' do
    before do
      fake_response = instance_double(HTTParty::Response, code: 200, body: '<html></html>')
      allow(HTTParty).to receive(:get).and_return(fake_response)
      fake_document = Nokogiri::HTML('<div><article></article></div>')
      allow(Nokogiri).to receive(:HTML).and_return(fake_document)
    end
    
    it 'returns an array of Car objects' do
      cars = scraper.scrape_data
      expect(cars).to be_an(Array)
      expect(cars.all? { |car| car.is_a?(Hash) }).to be true
    end
  end

  describe '#scrape_car_data' do
    before do
      fake_response = instance_double(HTTParty::Response, code: 200, body: '<html></html>')
      allow(HTTParty).to receive(:get).and_return(fake_response)
      fake_document = Nokogiri::HTML('<div><article></article></div>')
      allow(Nokogiri).to receive(:HTML).and_return(fake_document)
    end
  
    it 'returns a Hash object' do
      car = scraper.scrape_car_data(valid_url)
      expect(car).to be_an(Hash)
    end
  end

  describe '#read_cars_from_engine_box' do

    let(:html_with_links) do
      <<-HTML
        <html>
          <body>
            <div class="engine-box">
              <a href="http://example.com/car1">Car 1</a>
              <a href="http://example.com/car2">Car 2</a>
              <a href="http://example.com/car3">Car 3</a>
            </div>
          </body>
        </html>
      HTML
    end

    let(:html_without_links) do
      <<-HTML
        <html>
          <body>
            <div class="engine-box">
            </div>
          </body>
        </html>
      HTML
    end

    let(:html_without_engine_box) do
      <<-HTML
        <html>
          <body>
            <div class="other-box">
              <a href="http://example.com/car1">Car 1</a>
            </div>
          </body>
        </html>
      HTML
    end

    it 'returns an empty array when no links are present in the engine box' do
      document = Nokogiri::HTML(html_without_links)
      expect(scraper.read_cars_from_engine_box(document)).to eq([])
    end

    it 'returns an empty array when no engine box is present' do
      document = Nokogiri::HTML(html_without_engine_box)
      expect(scraper.read_cars_from_engine_box(document)).to eq([])
    end

    it 'returns an array of car links when links are present' do
      document = Nokogiri::HTML(html_with_links)
      expect(scraper.read_cars_from_engine_box(document)).to eq([
        "http://example.com/car1",
        "http://example.com/car2",
        "http://example.com/car3"
      ])
    end

  end
end