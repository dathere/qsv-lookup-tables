BEGIN {
    -- this is the BEGIN block, which is executed ONCE at the beginning
    -- we typically use it to initialize variables, load lookup tables and setup functions
    running_total = 0;
    running_total_after_tax = 0;
    amount_table = {};
    amount_table_with_salestax = {};

    -- we use the "dathere://" scheme to load "us-states-example.csv" from the
    -- https://github.com/dathere/qsv-lookup-tables repository
    us_states_lookup_headers_table = qsv_register_lookup("us_states", "dathere://us-states-example.csv")

    -- note how we use the qsv_log function to log to the qsv log file
    -- which you can enable by setting the QSV_LOG_LEVEL environment variable to "debug"
    -- e.g. `export QSV_LOG_LEVEL=debug`
    qsv_log("debug", "us_states_lookup_headers:", us_states_lookup_headers_table)
    qsv_log("info", "us_states lookup table:", us_states)
    qsv_log("info", `NY Capital: {us_states["NY"]["Capital"]} can be also {us_states.NY.Capital} or {us_states["NY"].Capital}`)

    -- a simple function to sum a table of numbers
    function sum(numbers_table: table): number
        local sum: number = 0;
        for _, v in ipairs(numbers_table) do
            sum = sum + v;
        end
        return sum;
    end
    
}!


----------------------------------------------------------------------------
-- this is the MAIN script loop, which is executed ONCE for each row in order

-- note the different ways we can access the columns of the current row
-- "Amount", the 2nd column and "State", the 3rd column in the lookup table
local amount_with_salestax: number = Amount + col[2] * (us_states[col["State"]]["Sales Tax (2023)"] / 100);
amount_with_salestax = col["Amount"] + col.Amount * (us_states[col.State]["Sales Tax (2023)"] / 100);
amount_with_salestax = col.Amount + Amount * (us_states[State]["Sales Tax (2023)"] / 100);

local Rate: number = us_states[State]["Sales Tax (2023)"];

-- _IDX is the current row index. We use it to store the amount_with_salestax in the amount_array
amount_table[_IDX] = Amount;
amount_table_with_salestax[_IDX] = amount_with_salestax;
running_total = running_total + Amount;
running_total_after_tax = running_total_after_tax + amount_with_salestax;

-- we round using Lua's powerful String library - https://www.lua.org/manual/5.4/manual.html#6.4
running_total = string.format("%.2f", running_total);
local rounded_running_total_after_tax = string.format("%.2f", running_total_after_tax);

-- we return multiple values, which are "mapped" to the columns specified in the qsv command
return {Rate, amount_with_salestax, running_total, rounded_running_total_after_tax};


----------------------------------------------------------------------------
END {
    -- and this is the END block, which is executed ONCE at the end

    -- first we use Lua's table library to unpack the contents of the amount_table into a list
    -- https://www.lua.org/manual/5.4/manual.html#6.6
    -- and then we use the builtin math library - https://www.lua.org/manual/5.4/manual.html#6.7
    -- to get the min and max values
    local min_amount: number = math.min(table.unpack(amount_table_with_salestax));
    local max_amount: number = math.max(table.unpack(amount_table_with_salestax));
    qsv_log("debug", `min_amount: {min_amount} max_amount: {max_amount}`)

    -- and here, we use our own sum function
    local grand_total_with_salestax = string.format("%.2f",sum(amount_table_with_salestax));
    local grand_total = string.format("%.2f",sum(amount_table));

    -- this message is returned to stderr
    -- _ROWCOUNT is a special variable that is set to the number of rows processed
    -- without an index, it is zero until we reach the END block
    return `Min/Max: {min_amount}/{max_amount} Grand total of {_ROWCOUNT} rows: {grand_total}/{grand_total_with_salestax}`;
}!
