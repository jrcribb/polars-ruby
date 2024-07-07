module Polars
  module IO
    # Read a CSV file into a DataFrame.
    #
    # @param source [Object]
    #   Path to a file or a file-like object.
    # @param has_header [Boolean]
    #   Indicate if the first row of dataset is a header or not.
    #   If set to false, column names will be autogenerated in the
    #   following format: `column_x`, with `x` being an
    #   enumeration over every column in the dataset starting at 1.
    # @param columns [Object]
    #   Columns to select. Accepts a list of column indices (starting
    #   at zero) or a list of column names.
    # @param new_columns [Object]
    #   Rename columns right after parsing the CSV file. If the given
    #   list is shorter than the width of the DataFrame the remaining
    #   columns will have their original name.
    # @param sep [String]
    #   Single byte character to use as delimiter in the file.
    # @param comment_char [String]
    #   Single byte character that indicates the start of a comment line,
    #   for instance `#`.
    # @param quote_char [String]
    #   Single byte character used for csv quoting.
    #   Set to nil to turn off special handling and escaping of quotes.
    # @param skip_rows [Integer]
    #   Start reading after `skip_rows` lines.
    # @param dtypes [Object]
    #   Overwrite dtypes during inference.
    # @param null_values [Object]
    #   Values to interpret as null values. You can provide a:
    #
    #   - `String`: All values equal to this string will be null.
    #   - `Array`: All values equal to any string in this array will be null.
    #   - `Hash`: A hash that maps column name to a null value string.
    # @param ignore_errors [Boolean]
    #   Try to keep reading lines if some lines yield errors.
    #   First try `infer_schema_length: 0` to read all columns as
    #   `:str` to check which values might cause an issue.
    # @param parse_dates [Boolean]
    #   Try to automatically parse dates. If this does not succeed,
    #   the column remains of data type `:str`.
    # @param n_threads [Integer]
    #   Number of threads to use in csv parsing.
    #   Defaults to the number of physical cpu's of your system.
    # @param infer_schema_length [Integer]
    #   Maximum number of lines to read to infer schema.
    #   If set to 0, all columns will be read as `:utf8`.
    #   If set to `nil`, a full table scan will be done (slow).
    # @param batch_size [Integer]
    #   Number of lines to read into the buffer at once.
    #   Modify this to change performance.
    # @param n_rows [Integer]
    #   Stop reading from CSV file after reading `n_rows`.
    #   During multi-threaded parsing, an upper bound of `n_rows`
    #   rows cannot be guaranteed.
    # @param encoding ["utf8", "utf8-lossy"]
    #   Lossy means that invalid utf8 values are replaced with `�`
    #   characters. When using other encodings than `utf8` or
    #   `utf8-lossy`, the input is first decoded im memory with
    #   Ruby.
    # @param low_memory [Boolean]
    #   Reduce memory usage at expense of performance.
    # @param rechunk [Boolean]
    #   Make sure that all columns are contiguous in memory by
    #   aggregating the chunks into a single array.
    # @param storage_options [Hash]
    #   Extra options that make sense for a
    #   particular storage connection.
    # @param skip_rows_after_header [Integer]
    #   Skip this number of rows when the header is parsed.
    # @param row_count_name [String]
    #   If not nil, this will insert a row count column with the given name into
    #   the DataFrame.
    # @param row_count_offset [Integer]
    #   Offset to start the row_count column (only used if the name is set).
    # @param sample_size [Integer]
    #   Set the sample size. This is used to sample statistics to estimate the
    #   allocation needed.
    # @param eol_char [String]
    #   Single byte end of line character.
    # @param truncate_ragged_lines [Boolean]
    #   Truncate lines that are longer than the schema.
    #
    # @return [DataFrame]
    #
    # @note
    #   This operation defaults to a `rechunk` operation at the end, meaning that
    #   all data will be stored continuously in memory.
    #   Set `rechunk: false` if you are benchmarking the csv-reader. A `rechunk` is
    #   an expensive operation.
    def read_csv(
      source,
      has_header: true,
      columns: nil,
      new_columns: nil,
      sep: ",",
      comment_char: nil,
      quote_char: '"',
      skip_rows: 0,
      dtypes: nil,
      null_values: nil,
      ignore_errors: false,
      parse_dates: false,
      n_threads: nil,
      infer_schema_length: N_INFER_DEFAULT,
      batch_size: 8192,
      n_rows: nil,
      encoding: "utf8",
      low_memory: false,
      rechunk: true,
      storage_options: nil,
      skip_rows_after_header: 0,
      row_count_name: nil,
      row_count_offset: 0,
      sample_size: 1024,
      eol_char: "\n",
      truncate_ragged_lines: false
    )
      Utils._check_arg_is_1byte("sep", sep, false)
      Utils._check_arg_is_1byte("comment_char", comment_char, false)
      Utils._check_arg_is_1byte("quote_char", quote_char, true)
      Utils._check_arg_is_1byte("eol_char", eol_char, false)

      projection, columns = Utils.handle_projection_columns(columns)

      storage_options ||= {}

      if columns && !has_header
        columns.each do |column|
          if !column.start_with?("column_")
            raise ArgumentError, "Specified column names do not start with \"column_\", but autogenerated header names were requested."
          end
        end
      end

      if projection || new_columns
        raise Todo
      end

      df = nil
      _prepare_file_arg(source) do |data|
        df = _read_csv_impl(
          data,
          has_header: has_header,
          columns: columns || projection,
          sep: sep,
          comment_char: comment_char,
          quote_char: quote_char,
          skip_rows: skip_rows,
          dtypes: dtypes,
          null_values: null_values,
          ignore_errors: ignore_errors,
          parse_dates: parse_dates,
          n_threads: n_threads,
          infer_schema_length: infer_schema_length,
          batch_size: batch_size,
          n_rows: n_rows,
          encoding: encoding == "utf8-lossy" ? encoding : "utf8",
          low_memory: low_memory,
          rechunk: rechunk,
          skip_rows_after_header: skip_rows_after_header,
          row_count_name: row_count_name,
          row_count_offset: row_count_offset,
          sample_size: sample_size,
          eol_char: eol_char,
          truncate_ragged_lines: truncate_ragged_lines
        )
      end

      if new_columns
        Utils._update_columns(df, new_columns)
      else
        df
      end
    end

    # @private
    def _read_csv_impl(
      file,
      has_header: true,
      columns: nil,
      sep: ",",
      comment_char: nil,
      quote_char: '"',
      skip_rows: 0,
      dtypes: nil,
      schema: nil,
      null_values: nil,
      missing_utf8_is_empty_string: false,
      ignore_errors: false,
      parse_dates: false,
      n_threads: nil,
      infer_schema_length: N_INFER_DEFAULT,
      batch_size: 8192,
      n_rows: nil,
      encoding: "utf8",
      low_memory: false,
      rechunk: true,
      skip_rows_after_header: 0,
      row_count_name: nil,
      row_count_offset: 0,
      sample_size: 1024,
      eol_char: "\n",
      raise_if_empty: true,
      truncate_ragged_lines: false,
      decimal_comma: false,
      glob: true
    )
      if Utils.pathlike?(file)
        path = Utils.normalize_filepath(file)
      else
        path = nil
        # if defined?(StringIO) && file.is_a?(StringIO)
        #   file = file.string
        # end
      end

      dtype_list = nil
      dtype_slice = nil
      if !dtypes.nil?
        if dtypes.is_a?(Hash)
          dtype_list = []
          dtypes.each do |k, v|
            dtype_list << [k, Utils.rb_type_to_dtype(v)]
          end
        elsif dtypes.is_a?(::Array)
          dtype_slice = dtypes
        else
          raise ArgumentError, "dtype arg should be list or dict"
        end
      end

      processed_null_values = Utils._process_null_values(null_values)

      if columns.is_a?(::String)
        columns = [columns]
      end
      if file.is_a?(::String) && file.include?("*")
        dtypes_dict = nil
        if !dtype_list.nil?
          dtypes_dict = dtype_list.to_h
        end
        if !dtype_slice.nil?
          raise ArgumentError, "cannot use glob patterns and unnamed dtypes as `dtypes` argument; Use dtypes: Mapping[str, Type[DataType]"
        end
        scan = scan_csv(
          file,
          has_header: has_header,
          sep: sep,
          comment_char: comment_char,
          quote_char: quote_char,
          skip_rows: skip_rows,
          dtypes: dtypes_dict,
          null_values: null_values,
          missing_utf8_is_empty_string: missing_utf8_is_empty_string,
          ignore_errors: ignore_errors,
          infer_schema_length: infer_schema_length,
          n_rows: n_rows,
          low_memory: low_memory,
          rechunk: rechunk,
          skip_rows_after_header: skip_rows_after_header,
          row_count_name: row_count_name,
          row_count_offset: row_count_offset,
          eol_char: eol_char,
          truncate_ragged_lines: truncate_ragged_lines,
          decimal_comma: decimal_comma,
          glob: glob
        )
        if columns.nil?
          return scan.collect
        elsif is_str_sequence(columns, allow_str: false)
          return scan.select(columns).collect
        else
          raise ArgumentError, "cannot use glob patterns and integer based projection as `columns` argument; Use columns: List[str]"
        end
      end

      projection, columns = Utils.handle_projection_columns(columns)

      rbdf =
        RbDataFrame.read_csv(
          file,
          infer_schema_length,
          batch_size,
          has_header,
          ignore_errors,
          n_rows,
          skip_rows,
          projection,
          sep,
          rechunk,
          columns,
          encoding,
          n_threads,
          path,
          dtype_list,
          dtype_slice,
          low_memory,
          comment_char,
          quote_char,
          processed_null_values,
          missing_utf8_is_empty_string,
          parse_dates,
          skip_rows_after_header,
          Utils.parse_row_index_args(row_count_name, row_count_offset),
          sample_size,
          eol_char,
          raise_if_empty,
          truncate_ragged_lines,
          decimal_comma,
          schema
        )
      Utils.wrap_df(rbdf)
    end

    # Read a CSV file in batches.
    #
    # Upon creation of the `BatchedCsvReader`,
    # polars will gather statistics and determine the
    # file chunks. After that work will only be done
    # if `next_batches` is called.
    #
    # @param source [Object]
    #   Path to a file or a file-like object.
    # @param has_header [Boolean]
    #   Indicate if the first row of dataset is a header or not.
    #   If set to False, column names will be autogenerated in the
    #   following format: `column_x`, with `x` being an
    #   enumeration over every column in the dataset starting at 1.
    # @param columns [Object]
    #   Columns to select. Accepts a list of column indices (starting
    #   at zero) or a list of column names.
    # @param new_columns [Object]
    #   Rename columns right after parsing the CSV file. If the given
    #   list is shorter than the width of the DataFrame the remaining
    #   columns will have their original name.
    # @param sep [String]
    #   Single byte character to use as delimiter in the file.
    # @param comment_char [String]
    #   Single byte character that indicates the start of a comment line,
    #   for instance `#`.
    # @param quote_char [String]
    #   Single byte character used for csv quoting, default = `"`.
    #   Set to nil to turn off special handling and escaping of quotes.
    # @param skip_rows [Integer]
    #   Start reading after `skip_rows` lines.
    # @param dtypes [Object]
    #   Overwrite dtypes during inference.
    # @param null_values [Object]
    #   Values to interpret as null values. You can provide a:
    #
    #   - `String`: All values equal to this string will be null.
    #   - `Array`: All values equal to any string in this array will be null.
    #   - `Hash`: A hash that maps column name to a null value string.
    # @param ignore_errors [Boolean]
    #   Try to keep reading lines if some lines yield errors.
    #   First try `infer_schema_length: 0` to read all columns as
    #   `:str` to check which values might cause an issue.
    # @param parse_dates [Boolean]
    #   Try to automatically parse dates. If this does not succeed,
    #   the column remains of data type `:str`.
    # @param n_threads [Integer]
    #   Number of threads to use in csv parsing.
    #   Defaults to the number of physical cpu's of your system.
    # @param infer_schema_length [Integer]
    #   Maximum number of lines to read to infer schema.
    #   If set to 0, all columns will be read as `:str`.
    #   If set to `nil`, a full table scan will be done (slow).
    # @param batch_size [Integer]
    #   Number of lines to read into the buffer at once.
    #   Modify this to change performance.
    # @param n_rows [Integer]
    #   Stop reading from CSV file after reading `n_rows`.
    #   During multi-threaded parsing, an upper bound of `n_rows`
    #   rows cannot be guaranteed.
    # @param encoding ["utf8", "utf8-lossy"]
    #   Lossy means that invalid utf8 values are replaced with `�`
    #   characters. When using other encodings than `utf8` or
    #   `utf8-lossy`, the input is first decoded im memory with
    #   Ruby. Defaults to `utf8`.
    # @param low_memory [Boolean]
    #   Reduce memory usage at expense of performance.
    # @param rechunk [Boolean]
    #   Make sure that all columns are contiguous in memory by
    #   aggregating the chunks into a single array.
    # @param skip_rows_after_header [Integer]
    #   Skip this number of rows when the header is parsed.
    # @param row_count_name [String]
    #   If not nil, this will insert a row count column with the given name into
    #   the DataFrame.
    # @param row_count_offset [Integer]
    #   Offset to start the row_count column (only used if the name is set).
    # @param sample_size [Integer]
    #   Set the sample size. This is used to sample statistics to estimate the
    #   allocation needed.
    # @param eol_char [String]
    #   Single byte end of line character.
    # @param truncate_ragged_lines [Boolean]
    #   Truncate lines that are longer than the schema.
    #
    # @return [BatchedCsvReader]
    #
    # @example
    #   reader = Polars.read_csv_batched(
    #     "./tpch/tables_scale_100/lineitem.tbl", sep: "|", parse_dates: true
    #   )
    #   reader.next_batches(5)
    def read_csv_batched(
      source,
      has_header: true,
      columns: nil,
      new_columns: nil,
      sep: ",",
      comment_char: nil,
      quote_char: '"',
      skip_rows: 0,
      dtypes: nil,
      null_values: nil,
      missing_utf8_is_empty_string: false,
      ignore_errors: false,
      parse_dates: false,
      n_threads: nil,
      infer_schema_length: N_INFER_DEFAULT,
      batch_size: 50_000,
      n_rows: nil,
      encoding: "utf8",
      low_memory: false,
      rechunk: true,
      skip_rows_after_header: 0,
      row_count_name: nil,
      row_count_offset: 0,
      sample_size: 1024,
      eol_char: "\n",
      raise_if_empty: true,
      truncate_ragged_lines: false,
      decimal_comma: false
    )
      projection, columns = Utils.handle_projection_columns(columns)

      if columns && !has_header
        columns.each do |column|
          if !column.start_with?("column_")
            raise ArgumentError, "Specified column names do not start with \"column_\", but autogenerated header names were requested."
          end
        end
      end

      if projection || new_columns
        raise Todo
      end

      BatchedCsvReader.new(
        source,
        has_header: has_header,
        columns: columns || projection,
        sep: sep,
        comment_char: comment_char,
        quote_char: quote_char,
        skip_rows: skip_rows,
        dtypes: dtypes,
        null_values: null_values,
        missing_utf8_is_empty_string: missing_utf8_is_empty_string,
        ignore_errors: ignore_errors,
        parse_dates: parse_dates,
        n_threads: n_threads,
        infer_schema_length: infer_schema_length,
        batch_size: batch_size,
        n_rows: n_rows,
        encoding: encoding == "utf8-lossy" ? encoding : "utf8",
        low_memory: low_memory,
        rechunk: rechunk,
        skip_rows_after_header: skip_rows_after_header,
        row_count_name: row_count_name,
        row_count_offset: row_count_offset,
        sample_size: sample_size,
        eol_char: eol_char,
        new_columns: new_columns,
        raise_if_empty: raise_if_empty,
        truncate_ragged_lines: truncate_ragged_lines,
        decimal_comma: decimal_comma
      )
    end

    # Lazily read from a CSV file or multiple files via glob patterns.
    #
    # This allows the query optimizer to push down predicates and
    # projections to the scan level, thereby potentially reducing
    # memory overhead.
    #
    # @param source [Object]
    #   Path to a file.
    # @param has_header [Boolean]
    #   Indicate if the first row of dataset is a header or not.
    #   If set to false, column names will be autogenerated in the
    #   following format: `column_x`, with `x` being an
    #   enumeration over every column in the dataset starting at 1.
    # @param sep [String]
    #   Single byte character to use as delimiter in the file.
    # @param comment_char [String]
    #   Single byte character that indicates the start of a comment line,
    #   for instance `#`.
    # @param quote_char [String]
    #   Single byte character used for csv quoting.
    #   Set to None to turn off special handling and escaping of quotes.
    # @param skip_rows [Integer]
    #   Start reading after `skip_rows` lines. The header will be parsed at this
    #   offset.
    # @param dtypes [Object]
    #   Overwrite dtypes during inference.
    # @param null_values [Object]
    #   Values to interpret as null values. You can provide a:
    #
    #   - `String`: All values equal to this string will be null.
    #   - `Array`: All values equal to any string in this array will be null.
    #   - `Hash`: A hash that maps column name to a null value string.
    # @param ignore_errors [Boolean]
    #   Try to keep reading lines if some lines yield errors.
    #   First try `infer_schema_length: 0` to read all columns as
    #   `:str` to check which values might cause an issue.
    # @param cache [Boolean]
    #   Cache the result after reading.
    # @param with_column_names [Object]
    #   Apply a function over the column names.
    #   This can be used to update a schema just in time, thus before
    #   scanning.
    # @param infer_schema_length [Integer]
    #   Maximum number of lines to read to infer schema.
    #   If set to 0, all columns will be read as `:str`.
    #   If set to `nil`, a full table scan will be done (slow).
    # @param n_rows [Integer]
    #   Stop reading from CSV file after reading `n_rows`.
    # @param encoding ["utf8", "utf8-lossy"]
    #   Lossy means that invalid utf8 values are replaced with `�`
    #   characters.
    # @param low_memory [Boolean]
    #   Reduce memory usage in expense of performance.
    # @param rechunk [Boolean]
    #   Reallocate to contiguous memory when all chunks/ files are parsed.
    # @param skip_rows_after_header [Integer]
    #   Skip this number of rows when the header is parsed.
    # @param row_count_name [String]
    #   If not nil, this will insert a row count column with the given name into
    #   the DataFrame.
    # @param row_count_offset [Integer]
    #   Offset to start the row_count column (only used if the name is set).
    # @param parse_dates [Boolean]
    #   Try to automatically parse dates. If this does not succeed,
    #   the column remains of data type `:str`.
    # @param eol_char [String]
    #   Single byte end of line character.
    # @param truncate_ragged_lines [Boolean]
    #   Truncate lines that are longer than the schema.
    #
    # @return [LazyFrame]
    def scan_csv(
      source,
      has_header: true,
      sep: ",",
      comment_char: nil,
      quote_char: '"',
      skip_rows: 0,
      dtypes: nil,
      null_values: nil,
      missing_utf8_is_empty_string: false,
      ignore_errors: false,
      cache: true,
      with_column_names: nil,
      infer_schema_length: N_INFER_DEFAULT,
      n_rows: nil,
      encoding: "utf8",
      low_memory: false,
      rechunk: true,
      skip_rows_after_header: 0,
      row_count_name: nil,
      row_count_offset: 0,
      parse_dates: false,
      eol_char: "\n",
      raise_if_empty: true,
      truncate_ragged_lines: false,
      decimal_comma: false,
      glob: true
    )
      Utils._check_arg_is_1byte("sep", sep, false)
      Utils._check_arg_is_1byte("comment_char", comment_char, false)
      Utils._check_arg_is_1byte("quote_char", quote_char, true)

      if Utils.pathlike?(source)
        source = Utils.normalize_filepath(source)
      end

      _scan_csv_impl(
        source,
        has_header: has_header,
        sep: sep,
        comment_char: comment_char,
        quote_char: quote_char,
        skip_rows: skip_rows,
        dtypes: dtypes,
        null_values: null_values,
        ignore_errors: ignore_errors,
        cache: cache,
        with_column_names: with_column_names,
        infer_schema_length: infer_schema_length,
        n_rows: n_rows,
        low_memory: low_memory,
        rechunk: rechunk,
        skip_rows_after_header: skip_rows_after_header,
        encoding: encoding,
        row_count_name: row_count_name,
        row_count_offset: row_count_offset,
        parse_dates: parse_dates,
        eol_char: eol_char,
        truncate_ragged_lines: truncate_ragged_lines
      )
    end

    # @private
    def _scan_csv_impl(
      file,
      has_header: true,
      sep: ",",
      comment_char: nil,
      quote_char: '"',
      skip_rows: 0,
      dtypes: nil,
      null_values: nil,
      ignore_errors: false,
      cache: true,
      with_column_names: nil,
      infer_schema_length: N_INFER_DEFAULT,
      n_rows: nil,
      encoding: "utf8",
      low_memory: false,
      rechunk: true,
      skip_rows_after_header: 0,
      row_count_name: nil,
      row_count_offset: 0,
      parse_dates: false,
      eol_char: "\n",
      truncate_ragged_lines: true
    )
      dtype_list = nil
      if !dtypes.nil?
        dtype_list = []
        dtypes.each do |k, v|
          dtype_list << [k, Utils.rb_type_to_dtype(v)]
        end
      end
      processed_null_values = Utils._process_null_values(null_values)

      rblf =
        RbLazyFrame.new_from_csv(
          file,
          sep,
          has_header,
          ignore_errors,
          skip_rows,
          n_rows,
          cache,
          dtype_list,
          low_memory,
          comment_char,
          quote_char,
          processed_null_values,
          infer_schema_length,
          with_column_names,
          rechunk,
          skip_rows_after_header,
          encoding,
          Utils.parse_row_index_args(row_count_name, row_count_offset),
          parse_dates,
          eol_char,
          truncate_ragged_lines
        )
      Utils.wrap_ldf(rblf)
    end

    private

    def _prepare_file_arg(file)
      if file.is_a?(::String) && file =~ /\Ahttps?:\/\//
        raise ArgumentError, "use URI(...) for remote files"
      end

      if defined?(URI) && file.is_a?(URI)
        require "open-uri"

        file = file.open
      end

      yield file
    end
  end
end