require "net/http"

class Downloader
  class InvalidUrlError < StandardError; end

  OUT_PATH = "./data"

  def call
    all_urls_valid?

    download_data
  end

  private

  STATIONS_2023  = "https://opendata.rijdendetreinen.nl/public/stations/stations-2023-09.csv" # Dutch and international railway stations as of September 2023
  DISTANCES_2022 = "https://opendata.rijdendetreinen.nl/public/tariff-distances/tariff-distances-2022-01.csv" # Distances for all stations (January 2022).

  def download_data
    urls_to_download.each do |url|
      next download(url) unless needs_extract?(url)

      download_and_extract(url)
    end
  end

  def all_urls_valid?
    urls_to_download.map do |url|
      url_valid?(url)
    end
  end

  def download(url)
    %x(wget #{url} -P #{OUT_PATH})
  end

  def download_and_extract(url)
    puts %x(curl -s -L #{url} | gunzip -c > #{OUT_PATH}/#{File.basename(url, '.gz')})
  end

  def url_valid?(url)
    url = URI.parse(url)
    req = Net::HTTP.new(url.host, url.port)
    req.use_ssl = true
    res = req.request_head(url.path)

    raise InvalidUrlError, url unless res.code == "200"

    true
  rescue => e
    puts [e, url]
    false
  end

  def needs_extract?(url)
    url.end_with?(".gz")
  end

  def urls_to_download
    [
      STATIONS_2023,
      DISTANCES_2022,
      *train_disruption_paths,
      *train_service_paths,
    ]
  end

  # https://opendata.rijdendetreinen.nl/public/disruptions/disruptions-2011.csv
  def train_disruption_paths
    (2011..2023).map do |year|
      "https://opendata.rijdendetreinen.nl/public/disruptions/disruptions-#{year}.csv"
    end
  end

  # https://opendata.rijdendetreinen.nl/public/services/services-2019.csv.gz
  # https://opendata.rijdendetreinen.nl/public/services/services-2023-01.csv.gz
  def train_service_paths
    years_wo_month = (2019..2025)
    years_w_month  = (2023..2025)

    urls_wo_month = years_wo_month.map do |year|
      "https://opendata.rijdendetreinen.nl/public/services/services-#{year}.csv.gz"
    end

    urls_w_month = years_w_month.map do |year|
      (1..12).map do |month|
        "https://opendata.rijdendetreinen.nl/public/services/services-#{year}-#{month < 10 ? 0 : nil}#{month}.csv.gz"
      end
    end.flatten

    urls_wo_month | urls_w_month
  end
end

Downloader.new.call