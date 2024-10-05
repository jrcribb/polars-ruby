module Polars
  module Selectors
    # @private
    class SelectorProxy < Expr
      def initialize(
        expr,
        name:,
        parameters: nil
      )
        self._rbexpr = expr._rbexpr
      end

      def ~
        if Utils.is_selector(self)
          inverted = Selectors.all - self
          # inverted._repr_override = f"~{self!r}"
        else
          inverted = ~as_expr
        end
        inverted
      end

      def -(other)
        if Utils.is_selector(other)
          SelectorProxy.new(
            meta._as_selector.meta._selector_sub(other),
            parameters: {"self" => self, "other" => other},
            name: "sub"
          )
        else
          as_expr - other
        end
      end

      def as_expr
        Expr._from_rbexpr(_rbexpr)
      end
    end

    # @private
    def self._selector_proxy_(...)
      SelectorProxy.new(...)
    end

    # Select all columns.
    #
    # @return [SelectorProxy]
    #
    # @example
    #   df = Polars::DataFrame.new(
    #     {
    #       "dt" => [Date.new(1999, 12, 31), Date.new(2024, 1, 1)],
    #       "value" => [1_234_500, 5_000_555]
    #     },
    #     schema_overrides: {"value" => Polars::Int32}
    #   )
    #
    # @example Select all columns, casting them to string:
    #   df.select(Polars.cs.all.cast(Polars::String))
    #   # =>
    #   # shape: (2, 2)
    #   # ┌────────────┬─────────┐
    #   # │ dt         ┆ value   │
    #   # │ ---        ┆ ---     │
    #   # │ str        ┆ str     │
    #   # ╞════════════╪═════════╡
    #   # │ 1999-12-31 ┆ 1234500 │
    #   # │ 2024-01-01 ┆ 5000555 │
    #   # └────────────┴─────────┘
    #
    # @example Select all columns *except* for those matching the given dtypes:
    #   df.select(Polars.cs.all - Polars.cs.numeric)
    #   # =>
    #   # shape: (2, 1)
    #   # ┌────────────┐
    #   # │ dt         │
    #   # │ ---        │
    #   # │ date       │
    #   # ╞════════════╡
    #   # │ 1999-12-31 │
    #   # │ 2024-01-01 │
    #   # └────────────┘
    def self.all
      _selector_proxy_(F.all, name: "all")
    end

    # Select all numeric columns.
    #
    # @return [SelectorProxy]
    #
    # @example
    #   df = Polars::DataFrame.new(
    #     {
    #       "foo" => ["x", "y"],
    #       "bar" => [123, 456],
    #       "baz" => [2.0, 5.5],
    #       "zap" => [0, 0]
    #     },
    #     schema_overrides: {"bar" => Polars::Int16, "baz" => Polars::Float32, "zap" => Polars::UInt8},
    #   )
    #
    # @example Match all numeric columns:
    #   df.select(Polars.cs.numeric)
    #   # =>
    #   # shape: (2, 3)
    #   # ┌─────┬─────┬─────┐
    #   # │ bar ┆ baz ┆ zap │
    #   # │ --- ┆ --- ┆ --- │
    #   # │ i16 ┆ f32 ┆ u8  │
    #   # ╞═════╪═════╪═════╡
    #   # │ 123 ┆ 2.0 ┆ 0   │
    #   # │ 456 ┆ 5.5 ┆ 0   │
    #   # └─────┴─────┴─────┘
    #
    # @example Match all columns *except* for those that are numeric:
    #   df.select(~Polars.cs.numeric)
    #   # =>
    #   # shape: (2, 1)
    #   # ┌─────┐
    #   # │ foo │
    #   # │ --- │
    #   # │ str │
    #   # ╞═════╡
    #   # │ x   │
    #   # │ y   │
    #   # └─────┘
    def self.numeric
      _selector_proxy_(F.col(NUMERIC_DTYPES), name: "numeric")
    end

    # Select all columns with alphabetic names (eg: only letters).
    #
    # @param ascii_only [Boolean]
    #   Indicate whether to consider only ASCII alphabetic characters, or the full
    #   Unicode range of valid letters (accented, idiographic, etc).
    # @param ignore_spaces [Boolean]
    #   Indicate whether to ignore the presence of spaces in column names; if so,
    #   only the other (non-space) characters are considered.
    #
    # @return [SelectorProxy]
    #
    # @note
    #   Matching column names cannot contain *any* non-alphabetic characters. Note
    #   that the definition of "alphabetic" consists of all valid Unicode alphabetic
    #   characters (`\p{Alphabetic}`) by default; this can be changed by setting
    #   `ascii_only: true`.
    #
    # @example
    #   df = Polars::DataFrame.new(
    #     {
    #       "no1" => [100, 200, 300],
    #       "café" => ["espresso", "latte", "mocha"],
    #       "t or f" => [true, false, nil],
    #       "hmm" => ["aaa", "bbb", "ccc"],
    #       "都市" => ["東京", "大阪", "京都"]
    #     }
    #   )
    #
    # @example Select columns with alphabetic names; note that accented characters and kanji are recognised as alphabetic here:
    #   df.select(Polars.cs.alpha)
    #   # =>
    #   # shape: (3, 3)
    #   # ┌──────────┬─────┬──────┐
    #   # │ café     ┆ hmm ┆ 都市 │
    #   # │ ---      ┆ --- ┆ ---  │
    #   # │ str      ┆ str ┆ str  │
    #   # ╞══════════╪═════╪══════╡
    #   # │ espresso ┆ aaa ┆ 東京 │
    #   # │ latte    ┆ bbb ┆ 大阪 │
    #   # │ mocha    ┆ ccc ┆ 京都 │
    #   # └──────────┴─────┴──────┘
    #
    # @example Constrain the definition of "alphabetic" to ASCII characters only:
    #   df.select(Polars.cs.alpha(ascii_only: true))
    #   # =>
    #   # shape: (3, 1)
    #   # ┌─────┐
    #   # │ hmm │
    #   # │ --- │
    #   # │ str │
    #   # ╞═════╡
    #   # │ aaa │
    #   # │ bbb │
    #   # │ ccc │
    #   # └─────┘
    #
    # @example
    #   df.select(Polars.cs.alpha(ascii_only: true, ignore_spaces: true))
    #   # =>
    #   # shape: (3, 2)
    #   # ┌────────┬─────┐
    #   # │ t or f ┆ hmm │
    #   # │ ---    ┆ --- │
    #   # │ bool   ┆ str │
    #   # ╞════════╪═════╡
    #   # │ true   ┆ aaa │
    #   # │ false  ┆ bbb │
    #   # │ null   ┆ ccc │
    #   # └────────┴─────┘
    #
    # @example Select all columns *except* for those with alphabetic names:
    #   df.select(~Polars.cs.alpha)
    #   # =>
    #   # shape: (3, 2)
    #   # ┌─────┬────────┐
    #   # │ no1 ┆ t or f │
    #   # │ --- ┆ ---    │
    #   # │ i64 ┆ bool   │
    #   # ╞═════╪════════╡
    #   # │ 100 ┆ true   │
    #   # │ 200 ┆ false  │
    #   # │ 300 ┆ null   │
    #   # └─────┴────────┘
    #
    # @example
    #   df.select(~Polars.cs.alpha(ignore_spaces: true))
    #   # =>
    #   # shape: (3, 1)
    #   # ┌─────┐
    #   # │ no1 │
    #   # │ --- │
    #   # │ i64 │
    #   # ╞═════╡
    #   # │ 100 │
    #   # │ 200 │
    #   # │ 300 │
    #   # └─────┘
    def self.alpha(ascii_only: false, ignore_spaces: false)
      # note that we need to supply a pattern compatible with the *rust* regex crate
      re_alpha = ascii_only ? "a-zA-Z" : "\\p{Alphabetic}"
      re_space = ignore_spaces ? " " : ""
      _selector_proxy_(
        F.col("^[#{re_alpha}#{re_space}]+$"),
        name: "alpha",
        parameters: {"ascii_only" => ascii_only, "ignore_spaces" => ignore_spaces},
      )
    end

    # Select all binary columns.
    #
    # @return [SelectorProxy]
    #
    # @example
    #   df = Polars::DataFrame.new({"a" => ["hello".b], "b" => ["world"], "c" => ["!".b], "d" => [":)"]})
    #   # =>
    #   # shape: (1, 4)
    #   # ┌──────────┬───────┬────────┬─────┐
    #   # │ a        ┆ b     ┆ c      ┆ d   │
    #   # │ ---      ┆ ---   ┆ ---    ┆ --- │
    #   # │ binary   ┆ str   ┆ binary ┆ str │
    #   # ╞══════════╪═══════╪════════╪═════╡
    #   # │ b"hello" ┆ world ┆ b"!"   ┆ :)  │
    #   # └──────────┴───────┴────────┴─────┘
    #
    # @example Select binary columns and export as a dict:
    #   df.select(Polars.cs.binary).to_h(as_series: false)
    #   # => {"a"=>["hello"], "c"=>["!"]}
    #
    # @example Select all columns *except* for those that are binary:
    #   df.select(~Polars.cs.binary).to_h(as_series: false)
    #   # => {"b"=>["world"], "d"=>[":)"]}
    def self.binary
      _selector_proxy_(F.col(Binary), name: "binary")
    end
  end

  def self.cs
    Polars::Selectors
  end
end
