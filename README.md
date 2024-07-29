# Scraper
Scraper, który wyciąga informacje o samochodach z serwisu autocentrum.pl

# Uruchomienie

Przed uruchomieniem trzeba zainstalować potrzebne gemy za pomocą komendy: bundle install \
Następnie za pomocą: bundle exec ruby script.rb \
Można uruchomić program, który wyciaga informacje z samochodach, a następnie zapisuje je do pliku

# Testy
Testy znajdują się w folderze '/spec' \
Raport z testów znajduję się w "/spec/rspec_results.html" \
Testy można uruchomić poprzez komendę 'rspec' w folderze projektu \
Uruchomić testy można także komendą "bundle exec rspec'

# Dokumentacja 
Dokumentacja (stworzona za pomoca yard) znajdują sie w foldrze '/doc' \
Dokumentacja tworzona jest za pomocą komendy:  bundle exec yard doc scraper.rb  script.rb  ./spec/*spec.rb --plugin rspec

# Logi
Logi (błędy i informacje) są zapisywane w folderze '/logs'

