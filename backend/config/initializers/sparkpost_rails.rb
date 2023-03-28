SparkPostRails.configure do |c|
  c.api_key = ENV["SPARKPOST_API_KEY"]
  c.html_content_only = true # otherwise devise emails come as plain text with html tags
end
