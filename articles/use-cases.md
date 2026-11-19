# Use case examples

``` r

library(parvenu)
```

parvenu pays off at 100,000 elements or more. There, its functions take
milliseconds where base R takes seconds or longer. Looking up 10,000
terms in 100,000 strings takes base R 38s, against 4ms. The examples
below are small so they run quickly.

For one call, seconds are often a fine wait. They turn into minutes with
dictionaries of thousands of terms, with capture groups or every match
from millions of strings, and with tens of millions of times. Where a
call repeats, as on every keystroke in a Shiny app or in every bootstrap
resample, even a fraction of a second adds up. The
[README](https://github.com/lhdjung/parvenu#when-the-wait-matters) has
the numbers.

## Coding free text with a keyword table

Free text often has to be sorted into categories: bank transactions into
spending categories, free-text medication fields into drugs, open survey
answers into codes. A keyword table does this.
[`par_match_term()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md)
finds the first keyword each string contains:

``` r

transactions <- c(
  "SUPERMART 0412 ZURICH",
  "CITY FUEL STATION 22",
  "Streamflix monthly plan",
  "SUPERMART FUEL 0412",
  "Transfer to savings",
  "Mart & More 17",
  NA
)

keywords <- data.frame(
  keyword = c("supermart fuel", "fuel", "supermart", "streamflix", "mart"),
  category = c("transport", "transport", "groceries", "subscriptions", "groceries")
)

i <- par_match_term(
  transactions,
  keywords$keyword,
  ignore_case = TRUE,
  whole_word = TRUE
)
data.frame(transactions, category = keywords$category[i])
#>              transactions      category
#> 1   SUPERMART 0412 ZURICH     groceries
#> 2    CITY FUEL STATION 22     transport
#> 3 Streamflix monthly plan subscriptions
#> 4     SUPERMART FUEL 0412     transport
#> 5     Transfer to savings          <NA>
#> 6          Mart & More 17     groceries
#> 7                    <NA>          <NA>
```

Three arguments make this work:

- **Order.** The first keyword in the table wins, wherever it occurs in
  the string. `"supermart fuel"` comes before `"supermart"`, so the fuel
  station at the supermarket counts as transport. Put specific keywords
  before general ones.
- **`whole_word = TRUE`.** Without it, `"mart"` would match inside
  `"SUPERMART"`, and a short keyword would turn up inside many longer
  words. With it, `"Mart & More"` still matches `"mart"`.
- **`ignore_case = TRUE`.** Statements mix `"SUPERMART"` and
  `"Supermart"`. This works in any script, so `"é"` matches `"É"`.

Rows with no keyword get `NA`, which shows what the table still misses:

``` r

transactions[is.na(i) & !is.na(transactions)]
#> [1] "Transfer to savings"
```

The same pattern works for:

- **Medication fields.** `"Aspirin 100mg 1x daily"` is matched against a
  list of drug names, longer names first (`"aspirin cardio"` before
  `"aspirin"`).
- **Open survey answers.** A codebook of keywords per code, such as
  `"commute"` and `"traffic"` for a transport code.
- **Literature screening.** Which drug, gene, or method from a list does
  each title or abstract name first?
- **Web logs.** User agents against a list of bot signatures. These are
  substrings of longer tokens (`"Googlebot/2.1"`), so leave `whole_word`
  off.

[`par_match_term()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md)
returns one term per string. That suits coding, where each string gets
one category. To keep only the strings that contain any term, use
`!is.na(par_match_term(x, terms))`.

## Tagging text with every term it names

For tagging rather than coding,
[`par_which_term()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md)
finds every term a string contains. It returns their positions in
`terms`, each once:

``` r

drugs <- c("aspirin", "ibuprofen", "paracetamol", "codeine")
abstracts <- c(
  "Ibuprofen versus paracetamol for pain after surgery",
  "Aspirin in primary prevention",
  "Physiotherapy for back pain"
)
tags <- par_which_term(abstracts, drugs, ignore_case = TRUE, whole_word = TRUE)
vapply(tags, function(i) paste(drugs[i], collapse = ", "), "")
#> [1] "ibuprofen, paracetamol" "aspirin"                ""
```

A long table of every pair of string and term is one step away:

``` r

data.frame(
  abstract = rep(seq_along(tags), lengths(tags)),
  drug = drugs[unlist(tags)]
)
#>   abstract        drug
#> 1        1   ibuprofen
#> 2        1 paracetamol
#> 3        2     aspirin
```

## Terms that are patterns

Where a term has several spellings or forms, use `fixed = FALSE`. The
terms are then regexes, in the syntax of
[`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md).
The earliest term in the list still wins:

``` r

tickets <- c(
  "Where is my parcel? Tracking no. 1Z999",
  "I want my money back",
  "Item arrived damaged, please refund",
  "Change my delivery address"
)
topics <- c(
  refund = "refund|money back|reimburs",
  damage = "damaged?|broken",
  shipping = "parcel|deliver(y|ed)|tracking"
)
names(topics)[par_match_term(tickets, topics, ignore_case = TRUE, fixed = FALSE)]
#> [1] "shipping" "refund"   "refund"   "shipping"
```

All the regexes are searched at once. That is much faster than a search
per term, but much slower than literal terms. So list the spellings as
literal terms where you can.

## Scoring text against a lexicon

Sentiment and topic scores often count how many words from a list each
text contains.
[`par_count_term()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md)
counts every hit of every term:

``` r

reviews <- c(
  "Great food, friendly staff, great value",
  "Cold food and rude staff",
  "Good coffee, bad parking",
  NA
)
positive <- c("great", "friendly", "good")
negative <- c("cold", "rude", "bad")

data.frame(
  reviews,
  positive = par_count_term(reviews, positive, ignore_case = TRUE, whole_word = TRUE),
  negative = par_count_term(reviews, negative, ignore_case = TRUE, whole_word = TRUE)
)
#>                                   reviews positive negative
#> 1 Great food, friendly staff, great value        3        0
#> 2                Cold food and rude staff        0        2
#> 3                Good coffee, bad parking        1        1
#> 4                                    <NA>       NA       NA
```

Dictionaries such as LIWC list stems, such as `"happ*"` for `"happy"`
and `"happiness"`. Pass the stems without the `*` and with
`whole_word = "start"`. A term then has to start a word but may end
inside one, so `"unhappy"` doesn’t count:

``` r

par_count_term(c("Happy and full of happiness", "Unhappy"), "happ", ignore_case = TRUE, whole_word = "start")
#> [1] 2 0
```

Hits are counted where they overlap, too. With `c("new york", "york")`,
the string `"new york"` has two. A term listed twice counts twice, so
pass `unique(terms)` if the list might repeat itself.

Lexicons such as AFINN rate each word from -5 to 5. With `weights`,
[`par_count_term()`](https://lhdjung.github.io/parvenu/reference/par_match_term.md)
sums the rating of every hit, in one pass for all words:

``` r

lexicon <- data.frame(word = c("great", "good", "bad", "rude"), score = c(3, 2, -2, -3))
par_count_term(reviews, lexicon$word, ignore_case = TRUE, whole_word = TRUE, weights = lexicon$score)
#> [1]  6 -3  0 NA
```

## Filtering and validating with a regex

[`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
is [`grepl()`](https://rdrr.io/r/base/grep.html) on all cores. It suits
large text columns:

``` r

log <- c(
  "2026-10-17 12:00:01 INFO request served",
  "2026-10-17 12:00:02 ERROR timeout after 30s",
  "2026-10-17 12:00:03 WARN slow query",
  "2026-10-17 12:00:04 ERROR disk full"
)
log[par_detect(log, " (ERROR|WARN) ")]
#> [1] "2026-10-17 12:00:02 ERROR timeout after 30s"
#> [2] "2026-10-17 12:00:03 WARN slow query"        
#> [3] "2026-10-17 12:00:04 ERROR disk full"
```

Validating identifiers works the same way. Here, rows whose ID doesn’t
have two capital letters followed by six digits:

``` r

id <- c("CH123456", "DE654321", "ch123456", "FR12345")
id[!par_detect(id, "^[A-Z]{2}[0-9]{6}$")]
#> [1] "ch123456" "FR12345"
```

`pattern` can also have one pattern per string. Here, each ID is checked
against the format of its own country:

``` r

formats <- c(CH = "^CH[0-9]{6}$", DE = "^DE[0-9]{6}$", FR = "^FR[0-9]{5}$")
country <- c("CH", "DE", "CH", "FR")
par_detect(id, formats[country])
#> [1]  TRUE  TRUE FALSE  TRUE
```

Each distinct pattern is compiled once, so a million rows with a few
formats cost little more than one pattern.

[`par_count()`](https://lhdjung.github.io/parvenu/reference/par_detect.md)
counts the matches instead, such as the words in each open survey
answer:

``` r

answers <- c("Too much traffic on my commute", "ok", "", NA)
par_count(answers, "\\w+")
#> [1]  6  1  0 NA
```

To find which of many literal terms appear, an alternation such as
`"aspirin|ibuprofen|paracetamol"` is fast in
[`par_detect()`](https://lhdjung.github.io/parvenu/reference/par_detect.md).
Rust’s regex engine searches all of its branches at once. For a
case-insensitive search over many terms, use
`par_match_term(ignore_case = TRUE)` instead, since `(?i)` makes a large
alternation slow.

Factor columns are matched by their levels, so a factor of a million
elements with 50 levels costs little more than matching 50 strings. See
[Performance: fast paths and slow
paths](https://lhdjung.github.io/parvenu/articles/performance.md) for
this and other ways to keep calls fast.

## Extracting and rewriting parts of strings

[`par_extract()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
returns the first match in each string, or `NA` where there is none.
Rust’s regex has no lookaround. To take part of a match, give it a
capture group and say which one:

``` r

notes <- c("BP 120/80, HR 72", "HR 95", "no vitals", NA)
par_extract(notes, "HR ([0-9]+)", group = 1)
#> [1] "72" "95" NA   NA
as.integer(par_extract(notes, "HR ([0-9]+)", group = 1))
#> [1] 72 95 NA NA
```

[`par_replace_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
replaces every match, as [`gsub()`](https://rdrr.io/r/base/grep.html)
does. In the replacement, `$1` stands for the first group, where
[`gsub()`](https://rdrr.io/r/base/grep.html) takes `\\1`:

``` r

people <- c("Smith, Jane", "Doe, John", "Prince")
par_replace_all(people, "^(\\w+), (\\w+)$", "$2 $1")
#> [1] "Jane Smith" "John Doe"   "Prince"
par_replace_all(c("phone: 044 123 45 67", NA), "[^0-9]", "")
#> [1] "0441234567" NA
```

[`par_replace()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
replaces only the first match, as
[`sub()`](https://rdrr.io/r/base/grep.html) does.
[`par_extract_all()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
returns every match, as a list with one character vector per string:

``` r

par_replace(c("  padded  ", "x"), "^ +", "")
#> [1] "padded  " "x"
par_extract_all(c("#rstats and #rust", "no tags", NA), "#(\\w+)", group = 1)
#> [[1]]
#> [1] "rstats" "rust"  
#> 
#> [[2]]
#> character(0)
#> 
#> [[3]]
#> [1] NA
```

Only R’s own thread can make R strings, so these run fastest where few
strings change, such as redacting the few that hold an email address.

[`par_locate()`](https://lhdjung.github.io/parvenu/reference/par_extract.md)
finds where the first match is, as a matrix of the first and last
character. Use it for [`substr()`](https://rdrr.io/r/base/substr.html)
or for highlighting:

``` r

par_locate(notes, "HR [0-9]+")
#>      start end
#> [1,]    12  16
#> [2,]     1   5
#> [3,]    NA  NA
#> [4,]    NA  NA
```

## Rewriting text with a dictionary

[`par_replace_term()`](https://lhdjung.github.io/parvenu/reference/par_replace_term.md)
replaces many literal terms at once, such as spelling variants,
abbreviations, or names to redact. It finds them all in one pass. A loop
of `gsub(fixed = TRUE)` would search every string once per term. It
could also replace text that an earlier replacement put there:

``` r

spelling <- data.frame(
  from = c("colour", "favour", "centre", "NYC"),
  to = c("color", "favor", "center", "New York City")
)
par_replace_term(
  c("Colour and flavour in the centre", "NYC, my favourite"),
  spelling$from,
  spelling$to,
  ignore_case = TRUE,
  whole_word = "start"
)
#> [1] "color and flavour in the center" "New York City, my favorite"
```

Hits don’t overlap. The leftmost wins. Among terms that start at the
same place, the one listed first wins, so list longer terms before their
prefixes. With `ignore_case = TRUE`, the replacement goes in as it is,
whatever the case of the hit.

## Lookups and joins

[`par_match()`](https://lhdjung.github.io/parvenu/reference/par_match.md)
and `%par_in%` return exactly what
[`match()`](https://rdrr.io/r/base/match.html) and `%in%` return, so
they can replace them anywhere. Some common uses:

``` r

orders <- data.frame(
  customer = c(101L, 205L, 101L, 999L),
  amount = c(20, 35, 12, 8)
)
customers <- data.frame(
  id = c(101L, 205L, 307L),
  region = c("north", "south", "east")
)

# Bring in a column from another table, as a left join would
orders$region <- customers$region[par_match(orders$customer, customers$id)]
orders
#>   customer amount region
#> 1      101     20  north
#> 2      205     35  south
#> 3      101     12  north
#> 4      999      8   <NA>

# Keep the rows whose key is in a set
orders[orders$customer %par_in% c(101L, 307L), ]
#>   customer amount region
#> 1      101     20  north
#> 3      101     12  north

# Check that every order has a known customer
all(orders$customer %par_in% customers$id)
#> [1] FALSE
```

Joins often need several key columns, such as a customer and a year.
[`par_match_rows()`](https://lhdjung.github.io/parvenu/reference/par_match_rows.md)
matches whole rows, without pasting the columns into strings:

``` r

orders$year <- c(2025, 2025, 2026, 2026)
targets <- data.frame(
  customer = c(101L, 101L, 205L),
  year = c(2025, 2026, 2025),
  goal = c(500, 400, 300)
)
i <- par_match_rows(orders[c("customer", "year")], targets[c("customer", "year")])
orders$goal <- targets$goal[i]
orders
#>   customer amount region year goal
#> 1      101     20  north 2025  500
#> 2      205     35  south 2025  300
#> 3      101     12  north 2026  400
#> 4      999      8   <NA> 2026   NA
```

[`par_match_rows()`](https://lhdjung.github.io/parvenu/reference/par_match_rows.md)
takes the first match, which suits a lookup table with one row per key.
When a key can repeat on both sides,
[`par_match_rows_all()`](https://lhdjung.github.io/parvenu/reference/par_match_all.md)
returns every matching pair, as a many-to-many join. Joined with itself,
a table returns its groups of equal rows. These may be numeric columns
in published data that are copies of each other:

``` r

keys <- data.frame(diff1 = c(0.1, 0.3, 0.1), diff2 = c(0.2, 0.2, 0.2))
pairs <- par_match_rows_all(keys, keys)
pairs[pairs$x < pairs$table, ] # each pair of equal rows once
#>   x table
#> 2 1     3
```

## Finding duplicates

[`par_duplicated()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md)
returns what [`duplicated()`](https://rdrr.io/r/base/duplicated.html)
returns. Use it to find repeated keys and remove repeated rows.
[`par_unique()`](https://lhdjung.github.io/parvenu/reference/par_duplicated.md)
returns what [`unique()`](https://rdrr.io/r/base/unique.html) returns:

``` r

ids <- c("a", "b", "a", "c", "b")
par_duplicated(ids)
#> [1] FALSE FALSE  TRUE FALSE  TRUE
par_unique(ids)
#> [1] "a" "b" "c"
sum(!par_duplicated(ids)) # number of distinct IDs
#> [1] 3

# Every row that has a twin, including the first one
visits <- data.frame(
  patient = c(1, 2, 1, 3),
  day = as.Date(c("2026-01-05", "2026-01-05", "2026-01-05", "2026-01-06"))
)
visits[par_duplicated(visits) | par_duplicated(visits, fromLast = TRUE), ]
#>   patient        day
#> 1       1 2026-01-05
#> 3       1 2026-01-05
```

## Binning by sorted breaks

[`par_find_interval()`](https://lhdjung.github.io/parvenu/reference/par_find_interval.md)
returns what
[`findInterval()`](https://rdrr.io/r/base/findInterval.html) returns:
for each value, how many of the sorted breaks are at or below it. That
bins values, such as ages into age groups:

``` r

age <- c(4, 17, 18, 45, 67, 90, NA)
breaks <- c(0, 18, 65)
groups <- c("child", "adult", "senior")
data.frame(age, group = groups[par_find_interval(age, breaks)])
#>   age  group
#> 1   4  child
#> 2  17  child
#> 3  18  adult
#> 4  45  adult
#> 5  67 senior
#> 6  90 senior
#> 7  NA   <NA>
```

It also finds which of a set of sorted, non-overlapping ranges each
value falls into, such as timestamps into shifts or prices into tax
brackets. Give the range starts as `vec`. With unsorted values, base
searches each one from scratch, so the threads help most. 10 million
values take tens of milliseconds, where base takes about a second.

## Parsing dates and times

Reading dates from text is one of the slowest common steps in base R. A
million dates take [`as.Date()`](https://rdrr.io/r/base/as.Date.html)
seconds.
[`par_as_date()`](https://lhdjung.github.io/parvenu/reference/par_as_date.md)
and
[`par_as_posixct()`](https://lhdjung.github.io/parvenu/reference/par_as_date.md)
return what [`as.Date()`](https://rdrr.io/r/base/as.Date.html) and
[`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) return, in
milliseconds:

``` r

par_as_date(c("2026-01-05", "2026-02-30", NA))
#> [1] "2026-01-05" NA           NA
par_as_date("05.01.2026", format = "%d.%m.%Y")
#> [1] "2026-01-05"
par_as_posixct("2026-01-05 08:30:00.25", tz = "UTC")
#> [1] "2026-01-05 08:30:00 UTC"
```

Times are parsed in Rust in any time zone. Outside UTC, base R’s own
code places the start and end of each day, and every time of a day whose
clock changes, which takes longer. Times that span more days than there
are times, and uncommon formats, go to base R.
[`?par_as_date`](https://lhdjung.github.io/parvenu/reference/par_as_date.md)
lists the formats that Rust reads.

## Ranks, group sums, and interpolation

[`par_rank()`](https://lhdjung.github.io/parvenu/reference/par_rank.md)
returns what [`rank()`](https://rdrr.io/r/base/rank.html) returns. Base
[`rank()`](https://rdrr.io/r/base/rank.html) is slow where values tie.
[`par_rowsum()`](https://lhdjung.github.io/parvenu/reference/par_rowsum.md)
sums values by group, as
[`rowsum()`](https://rdrr.io/r/base/rowsum.html) does.
[`par_approx()`](https://lhdjung.github.io/parvenu/reference/par_approx.md)
interpolates as [`approx()`](https://rdrr.io/r/stats/approxfun.html)
does:

``` r

scores <- c(ann = 3, bob = 1, cat = 3, dan = NA)
par_rank(scores, ties.method = "min", na.last = "keep")
#> ann bob cat dan 
#>   2   1   2  NA

sales <- c(10, 20, 5, 15)
region <- c("north", "south", "north", "south")
par_rowsum(sales, region)
#>       [,1]
#> north   15
#> south   35

# Temperature at each hour, from readings at irregular times
readings <- data.frame(hour = c(0, 2.5, 6, 9), temp = c(4, 3, 8, 12))
par_approx(readings$hour, readings$temp, xout = 0:9)$y
#>  [1]  4.000000  3.600000  3.200000  3.714286  5.142857  6.571429  8.000000
#>  [8]  9.333333 10.666667 12.000000
```
