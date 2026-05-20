# Infers PostgreSQL column types by sampling rows from a CSV or gzipped-CSV file.
# Lives in lib/ (autoloaded) so it can be used from both the web process (admin
# upload actions) and rake tasks without pulling in the full CartoDB rake helpers.
module CsvColumnTypeInferrer
  # Returns a Hash of { column_name => pg_type_string }.
  # Supported types: bigint, double precision, boolean, text.
  def self.infer(file_path, limit: 2_000)
    require "csv"
    require "zlib"

    col_samples = {}

    opener = file_path.to_s.end_with?(".gz") \
      ? ->(p, &b) { Zlib::GzipReader.open(p, &b) } \
      : ->(p, &b) { File.open(p, encoding: "UTF-8", &b) }

    opener.call(file_path) do |io|
      csv = CSV.new(io, headers: true)
      csv.each_with_index do |row, idx|
        break if idx >= limit

        row.each do |col, val|
          col_samples[col] ||= []
          col_samples[col] << val if val && !val.empty?
        end
      end
    end

    col_samples.transform_values do |vals|
      next "text" if vals.empty?

      if vals.all? { |v| v.match?(/\A-?\d+\z/) }
        "bigint"
      elsif vals.all? { |v| v.match?(/\A-?\d+\.?\d*(?:[eE][+-]?\d+)?\z/) }
        "double precision"
      elsif vals.all? { |v| v.match?(/\A(?:true|false|t|f|yes|no)\z/i) }
        "boolean"
      else
        "text"
      end
    end
  end
end
