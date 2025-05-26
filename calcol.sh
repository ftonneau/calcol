#!/bin/sh

# This script colorizes the output of cal(1). The colors employed can be
# customized via environment variables.

# Author: Francois Tonneau
# License: MIT

command cal "$@" --color=always | awk ' # => awk begin

function import_vars() {
    Env_sat = ENVIRON["CALCOL_SAT"]
    if (!Env_sat) Env_sat = "Sat"

    Env_sun = ENVIRON["CALCOL_SUN"]
    if (!Env_sun) Env_sun = "Sun"

    Env_head = ENVIRON["CALCOL_HEAD"]
    if (!Env_head) Env_head = "0,2"

    Env_month = ENVIRON["CALCOL_MONTH"]
    if (!Env_month) Env_month = "2,,b"

    Env_weekend = ENVIRON["CALCOL_WEEKEND"]
    if (!Env_weekend) Env_weekend = "3"

    Env_weeknum = ENVIRON["CALCOL_WEEKNUM"]
    if (!Env_weeknum) Env_weeknum = "8"

    Env_year = ENVIRON["CALCOL_YEAR"]
    if (!Env_year) Env_year = "2,,b"

    Env_focus = ENVIRON["CALCOL_FOCUS"]
    if (!Env_focus) Env_focus = "0,1"
}

function define_styles() {
    Head_style = ansi_codes(Env_head)
    Month_style = ansi_codes(Env_month)
    Weekend_style = ansi_codes(Env_weekend)
    Weeknum_style = ansi_codes(Env_weeknum)
    Year_style = ansi_codes(Env_year)

    Focus_style = ansi_codes(Env_focus)
}

function ansi_codes(specs,
        parts, foreground, background, effect) {
    split(specs, parts, ",")
    if (parts[1] ~ /^[[:digit:]]+$/) {
        num = parts[1] + 0
        foreground = num < 8 ? "\033[3" num "m" : "\033[38;5;" num "m"
    }
    if (parts[2] ~ /^[[:digit:]]+$/) {
        num = parts[2] + 0
        background = num < 8 ? "\033[4" num "m" : "\033[48;5;" num "m"
    }
    if (parts[3] ~ /b/) effect = "\033[1m"
    if (parts[3] ~ /u/) effect = effect "\033[4m"
    return Plain foreground background effect
}

function define_constants() {
    Plain = "\033[0m"
    Date_signal = "\033[7m"    # reverse mode

    D = "[[:alpha:]]+"
    Any_month = "[[:alpha:]]+( [[:digit:]]+)?"
    Any_year = "[[:digit:]][[:digit:]][[:digit:]][[:digit:]]"
    Gutter = "  +" # => at least two spaces
}

function has_punct(row) {
    return bleached(row) ~ /[[:punct:]]/
}

function bleached(row) {
    # Remove all ANSI terminal codes to get a clear view of actual
    # letters, digits, and punctuation.
    gsub(/[^[:print:]][^m]+m/, "", row)
    return row
}

function has_head(row) {
    # Day heads are at row start and/or comprise a full week.
    return starts_with_letter(row) || wordcount(row) >=7
}

function starts_with_letter(row) {
    return bleached(row) ~ /^[[:alpha:]]/
}

function wordcount(row,
        cleanrow) {
    cleanrow = bleached(row)
    return gsub(/[[:alpha:]]+/, "&", cleanrow)
}

function get_global_settings(row) {
    # Note: this detection procedure is valid only when called on a row
    # with a header.
    if (starts_with_letter(row)) {
        if (!has_digit(row)) Horizontal = 1
    }
    else {
        Horizontal = 1
        Use_weeknums = 1
    }

    match(row, /[[:alpha:]]+/)  # => match to first day head
    Headwidth = RLENGTH
    Sat = substr(Env_sat, 1, Headwidth)
    Sun = substr(Env_sun, 1, Headwidth)
    Sat_or_sun = "(" Sat "|" Sun ")"

    if (Horizontal) {
        Full_header = D " " D " " D " " D " " D " " D " " D # => a week
    }
    else {
        Full_header = "^" D # => a single day head at row start
    }
    Global_settings = 1
}

function has_digit(row) {
    return bleached(row) ~ /[[:digit:]]/
}

function get_column_model(row) {
    Column_model = row
}

function is_title_year(row) {
    return bleached(row) ~ "^ *" Any_year " *$"
}

function has_month(row) {
    return wordcount(row) > 0 && !has_head(row)
}

function has_date(row) {
    if (Horizontal) return has_digit(row) && !has_year(row)
    else return has_head(row)
}

function has_year(row) {
    return bleached(row) ~ Any_year
}

function remove(string, substring,
        before, after, left, right) {
    before = index(string, substring) - 1
    if (before) left = substr(string, 1, before)
    after = index(string, substring) + length(substring)
    right = substr(string, after)
    return left right
}

function paint_date_columns(row,
        nweeks, week, m) {
    Timeframe = Column_model

    # Moving left to right along weeks, we mark the positions of week
    # number (if needed), saturday, and sunday.
    Total_marks = 0
    nweeks = gsub(Full_header, "&", Timeframe)
    for (week = 1; week <= nweeks; week++) {
        if (Use_weeknums) add_weeknum_mark()
        add_weekend_mark()
        add_weekend_mark()
    }

    # We paint marks one after the other, moving right to left so that
    # inserting color codes does not disturb leftward char positions.
    for (m = Total_marks; m >= 1; m--) {
        row = paint(row, Mark_pos[m], Mark_style[m], Mark_width[m], Plain)
    }

    return row
}

function add_weeknum_mark() {
    find_next_match(Gutter)
    add_mark(RSTART, RLENGTH, Weeknum_style)
}

function find_next_match(pattern,
        col, wipe) {
    match(Timeframe, pattern)
    for (col = 1; col <= RLENGTH; col++) wipe = wipe "-"
    sub(pattern, wipe, Timeframe)     # => prevent rematching
}

function add_mark(pos, width, style) {
    Total_marks++
    Mark_pos[Total_marks] = pos
    Mark_width[Total_marks] = width
    Mark_style[Total_marks] = style
}

function add_weekend_mark() {
    find_next_match(Sat_or_sun)
    # As we add saturday and sunday marks, we must not forget to bring
    # the focus mark along if needed.
    if (Focus_pos && !Focus_marked && RSTART > Focus_pos) {
        add_mark(Focus_pos, Headwidth, Focus_style)
        add_mark(RSTART, RLENGTH, Weekend_style)
        Focus_marked = 1
    }
    else if (RSTART == Focus_pos) {
        add_mark(Focus_pos, Headwidth, Focus_style)
        Focus_marked = 1
    }
    else {
        add_mark(RSTART, RLENGTH, Weekend_style)
    }
}

function paint(row, pos, style_on, width, style_off,
        left, middle, right) {
    if (pos > 1) left = substr(row, 1, pos - 1)
    middle = Plain style_on substr(row, pos, width) style_off
    right = substr(row, pos + width)
    return left middle right
}

function paint_date_row(row,
        style) {
    # Paint row from right to left, so that inserting color codes does
    # not disturb leftward char positions.
    if (row ~ "^" Sat_or_sun) {
        style = Weekend_style
        row = row Plain
    }
    if (Focus_pos) {
        row = paint(row, Focus_pos, Focus_style, Headwidth, Plain style)
    }
    sub(Full_header, "&" style, row)
    return row
}

function is_weeknum_row(row) {
    if (Horizontal) return 0
    if (wordcount(row) || has_year(row)) return 0
    return has_digit(row)
}

BEGIN {
    import_vars()
    define_styles()
    define_constants()
}

{
    if (has_punct($0)) {
        Shows_help_or_version = 1
    }

    if (Shows_help_or_version) { # => avoid any coloring:
        print
        next
    }

    if (has_head($0)) {
        if (!Global_settings) get_global_settings($0)
        if (Horizontal) get_column_model($0)
    }

    if (is_title_year($0)) {
        gsub(Any_year, Year_style "&" Plain)
    }
    if (has_month($0)) {
        gsub(Any_month, Month_style "&" Plain)
    }
    if (has_date($0)) {
        Focus_pos = index($0, Date_signal)
        if (Focus_pos) {
            $0 = bleached($0)
            Focus_marked = 0
        }
        if (Horizontal) $0 = paint_date_columns($0)
        else $0 = paint_date_row($0)
    }
    if (has_head($0)) {
        gsub(Full_header, Head_style "&" Plain)
    }
    if (is_weeknum_row($0)) {
        gsub(/[[:digit:]+]/, Weeknum_style "&" Plain)
    }
    print
}

# <= awk end '

