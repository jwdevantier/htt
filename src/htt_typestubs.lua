---@meta

---HTT utility API
---@class htt
---@field str httStrModule nil
---@field env httEnvModule nil
---@field tcp httTcpModule nil
---@field time httTimeModule nil
---@field fs httFsModule nil
---@field is httIsModule nil
---@field json httJsonModule JSON de- serialization functions
htt = {}

---@class httStrModule
htt.str = {}


---True iff. `value` is null.
---@param sep string string to insert between each concatenated element
---@param list table a list of strings to concatenate
---@return string Concatenated strings
function htt.str.join(sep, list) end

---Converts a Lua value into a formatted string representation with proper indentation.
---
---Note: handles the formatting of tables and strings. Will use tostring() otherwise.
---@param value any The Lua value to stringify (table, string, number, etc.)
---@param indentation string The base indentation prefix for each line of output
---@return string The formatted string representation of the value
function htt.str.stringify(value, indentation) end

---Returns whether the string begins with the specified prefix
---@param str string The string to check
---@param prefix string The prefix to look for at the start of the string
---@return boolean True if str starts with prefix, false otherwise
function htt.str.starts_with(str, prefix) end

---@class httEnvModule
htt.env = {}


---Return major- and minor version of the HTT API
---
---The scheme is thus:
---The major version is incremented when *existing* APIs change
---The minor version is incremented when new APIs are added
---@return integer major The API major version
---@return integer minor The API minor version
function htt.env.api_version() end

---Return path to the HTT binary running the script.
---
---This can be useful if you want to call HTT on another script to parse in an isolated process
---@return string htt_bin_path Absolute path to the HTT binary
function htt.env.htt_path() end

---Return path to the base output directory.
---
---HTT determines a base output path which is the base path from which all relative
---output paths from calls to `render` will place their files.
---
---By default, this path is the same directory as the script being run, but command-line
---flags can override this.
---@return string out_path Absolute path to the output directory
function htt.env.out_path() end

---@class httTcpModule
htt.tcp = {}


---Value representing an IP address and port
---@alias Endpoint userdata

---@class htt.tcp.Stream
htt.tcp.Stream = {}

---Receive data from TCP stream
---@param buf htt.tcp.Buffer Buffer of data to send
---@param n integer if provided, read exactly `n` bytes
---@return integer? Number of bytes sent
---@return string? Error message, on error
function htt.tcp.Stream:recv(buf, n) end

---Receive at least N bytes from TCP stream
---@param buf htt.tcp.Buffer Buffer of data to send
---@param n integer read at least this many bytes
---@return integer? Number of bytes sent
---@return string? Error message, on error
function htt.tcp.Stream:recv_at_least(buf, n) end

---Send bytes over TCP stream
---@param buffer htt.tcp.Buffer Buffer
---@param n integer? if set, send the first n bytes, not entire buffer
---@return string? error Error message, if any
function htt.tcp.Stream:send(buffer, n) end

---@class htt.tcp.Buffer
htt.tcp.Buffer = {}

---Return number of bytes between current position and end of buffer
---
---NOTE: the position is modified by `seek()` and reported by `tell()`
---@return integer? Number of bytes from current position to end of buffer
function htt.tcp.Buffer:remaining() end

---Return current size of the buffer in bytes.
---
---NOTE: Use setSize to grow or shrink the buffer.
---@return integer? Size of buffer in bytes
function htt.tcp.Buffer:size() end

---Return current size of the buffer in bytes.
---
---NOTE: Use setSize to grow or shrink the buffer.
---@param N integer nil
---@return integer? Size of buffer in bytes
function htt.tcp.Buffer:set_size(N) end

---Sets the buffer position to N bytes from the start
---@param N integer The byte offset to seek to
function htt.tcp.Buffer:seek(N) end

---Reports the offset, in bytes, from the start of the buffer.
---@return integer position Offset, in bytes, from the buffer's start
function htt.tcp.Buffer:tell() end

---Write string to buffer.
---
---Raises an error if writing the string would go out-of-bounds.
---@param str string the string to write
function htt.tcp.Buffer:write_string(str) end

---Write boolean to buffer.
---
---Raises an error if writing the boolean would go out-of-bounds.
---@param val boolean the value to write
function htt.tcp.Buffer:write_bool(val) end

---Read `len` bytes from buffer and return it as a string.
---
---Raises an error if reading the string would go out-of-bounds.
---@param len integer length, in bytes, of string
---@return string The string value
function htt.tcp.Buffer:read_string(len) end

---Read boolean value from buffer
---
---Reads a full byte, anything but 0 is treated as true.
---@return boolean The boolean value
function htt.tcp.Buffer:read_bool() end

---Write signed 8 bits integer to buffer in big-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i8be(val) end

---Write signed 16 bits integer to buffer in big-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i16be(val) end

---Write signed 32 bits integer to buffer in big-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i32be(val) end

---Write signed 64 bits integer to buffer in big-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i64be(val) end

---Write signed 8 bits integer to buffer in little-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i8le(val) end

---Write signed 16 bits integer to buffer in little-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i16le(val) end

---Write signed 32 bits integer to buffer in little-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i32le(val) end

---Write signed 64 bits integer to buffer in little-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i64le(val) end

---Write signed 8 bits integer to buffer
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i8(val) end

---Write signed 16 bits integer to buffer
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i16(val) end

---Write signed 32 bits integer to buffer
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i32(val) end

---Write signed 64 bits integer to buffer
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_i64(val) end

---Write unsigned 8 bits integer to buffer in big-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u8be(val) end

---Write unsigned 16 bits integer to buffer in big-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u16be(val) end

---Write unsigned 32 bits integer to buffer in big-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u32be(val) end

---Write unsigned 64 bits integer to buffer in big-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u64be(val) end

---Write unsigned 8 bits integer to buffer in little-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u8le(val) end

---Write unsigned 16 bits integer to buffer in little-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u16le(val) end

---Write unsigned 32 bits integer to buffer in little-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u32le(val) end

---Write unsigned 64 bits integer to buffer in little-endian order
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u64le(val) end

---Write unsigned 8 bits integer to buffer
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u8(val) end

---Write unsigned 16 bits integer to buffer
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u16(val) end

---Write unsigned 32 bits integer to buffer
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u32(val) end

---Write unsigned 64 bits integer to buffer
---
---Raises error if writing value would be out-of-bounds
---@param val integer value to write
function htt.tcp.Buffer:write_u64(val) end

---Reads a signed 8 bits integer from buffer, converts from big-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_i8be() end

---Reads a signed 16 bits integer from buffer, converts from big-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_i16be() end

---Reads a signed 32 bits integer from buffer, converts from big-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_i32be() end

---Reads a signed 64 bits integer from buffer, converts from big-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_i64be() end

---Reads a signed 8 bits integer from buffer, converts from little-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_i8le() end

---Reads a signed 16 bits integer from buffer, converts from little-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_i16le() end

---Reads a signed 32 bits integer from buffer, converts from little-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_i32le() end

---Reads a signed 64 bits integer from buffer, converts from little-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_i64le() end

---Reads a signed 8 bits integer from buffer
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value
function htt.tcp.Buffer:read_i8() end

---Reads a signed 16 bits integer from buffer
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value
function htt.tcp.Buffer:read_i16() end

---Reads a signed 32 bits integer from buffer
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value
function htt.tcp.Buffer:read_i32() end

---Reads a signed 64 bits integer from buffer
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value
function htt.tcp.Buffer:read_i64() end

---Reads a unsigned 8 bits integer from buffer, converts from big-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_u8be() end

---Reads a unsigned 16 bits integer from buffer, converts from big-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_u16be() end

---Reads a unsigned 32 bits integer from buffer, converts from big-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_u32be() end

---Reads a unsigned 64 bits integer from buffer, converts from big-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_u64be() end

---Reads a unsigned 8 bits integer from buffer, converts from little-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_u8le() end

---Reads a unsigned 16 bits integer from buffer, converts from little-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_u16le() end

---Reads a unsigned 32 bits integer from buffer, converts from little-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_u32le() end

---Reads a unsigned 64 bits integer from buffer, converts from little-endian- to native byte-order
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value converted to native byte order
function htt.tcp.Buffer:read_u64le() end

---Reads a unsigned 8 bits integer from buffer
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value
function htt.tcp.Buffer:read_u8() end

---Reads a unsigned 16 bits integer from buffer
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value
function htt.tcp.Buffer:read_u16() end

---Reads a unsigned 32 bits integer from buffer
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value
function htt.tcp.Buffer:read_u32() end

---Reads a unsigned 64 bits integer from buffer
---
---Raises error if reading value would be out-of-bounds
---@return integer The integer value
function htt.tcp.Buffer:read_u64() end

---Create a new buffer object
---
---Buffers can grow and shrink, but only in response to explicit `set_size` calls.
---Otherwise, attempting to read- or write past buffer bounds will raise an error.
---
---A buffer maintains a position, which marks the start of every read- and write
---operation. Every read- and write- operation will appropriately advance the position.
---To get the position, call `tell()`, which returns some value between 0 and the buffer's size.
---You can also manually change the position by calling `seek(N)`.
---@param size integer initial size, in bytes, of buffer
---@return htt.tcp.Buffer buf The new buffer object
---@return string? err Error message, if any
function htt.tcp.buffer(size) end

---Returns an address structure which can be passed to `connect`.
---@param ip string the IPv4/IPv6 address
---@param port integer the port of the server
---@return Endpoint Reference to the endpoint (IP and port), if successful
---@return string Error message, if any
function htt.tcp.addr(ip, port) end

---Connect to a TCP server at the IP-address and port specified by `endpoint`
---@param endpoint Endpoint structure representing the endpoint
---@return htt.tcp.Stream stream Stream with which to communicate with the server.
---@return string error Error message, if any occurred.
function htt.tcp.connect(endpoint) end

---@class httTimeModule
htt.time = {}


---a value meaning some number of nanoseconds
---@alias nanosecond integer

---Return time, in seconds, relative to UTC 1970-01-01.
---
---Return-value is signed because it is possible to have dates before the epoch
---@return integer time_s Seconds since the epoch
function htt.time.timestamp() end

---Return time, in milliseconds, relative to UTC 1970-01-01.
---
---Return-value is signed to allow for dates before the epoch.
---@return integer time_ms Milliseconds since the epoch
function htt.time.timestamp_ms() end

---Sleep for some duration of time measured in nanoseconds*.
---
---Underlying implementation mentions that spurious wakeups are possible
---and that no precision of timing is guaranteed.
---@param duration_ns nanosecond duration, in nanoseconds, to sleep
function htt.time.sleep(duration_ns) end

---The number of nanoseconds per microsecond.
---@type nanosecond
htt.time.ns_per_us = nil

---The number of nanoseconds per millisecond.
---@type nanosecond
htt.time.ns_per_ms = nil

---The number of nanoseconds per second.
---@type nanosecond
htt.time.ns_per_s = nil

---The number of nanoseconds per minute.
---@type nanosecond
htt.time.ns_per_min = nil

---@class httFsModule
htt.fs = {}


---@class htt.fs.ftype
---@field label string string representation of enum value

---An iterator function returning pairs of path and 'file' type
---
---An iterator function which, when called, returns a pair of values
---until such time as there are no more values.
---
---The path value is the file-system path to the entry (file or directory)
---and the ftype value is an enumeration type describing the actual type of
---the entry, notably whether a file or directory.
---@alias DirIterator fun(): path, htt.fs.ftype

---A string representing some file system path.
---
---Note that the actual path separator string can be gotten with htt.fs.sep.
---@alias path string

---Return handle to directory at current working directory (CWD).
---@return htt.fs.Dir dir Handle to current working directory
function htt.fs.cwd() end

---The string used for path separation on this platform.
---@type string
htt.fs.sep = nil

---Convert `path` from using '/' to using the OS-dependent path separator.
---@param path path file-system path with '/' used as path separator
---@return path Path converted to using OS-dependent path separator
function htt.fs.path(path) end

---Joins a series of path components into a path using the OS-specific path separator
---@param ... string path components
---@return path Joined path
function htt.fs.path_join(...) end

---Given a path, strips last component from path and returns it
---
---If path is the root directory, returns the empty string.
---@param path path file-system path string
---@return path Path to parent directory
function htt.fs.dirname(path) end

---Returns the last component of a file path, excluding trailing separators.
---
---Returns empty string if applied to root path or root of drive.
---@param path path file-system path string
---@return string Name of last component in path
function htt.fs.basename(path) end

---Returns the OS-specific 'null' file, such as /dev/null for POSIX-compliant systems.
---@return path Path to null file
function htt.fs.null_file() end

---@class htt.fs.Dir
htt.fs.Dir = {}

---Get canonical absolute path to this directory.
---@return path? Path on success, nil otherwise
function htt.fs.Dir:path() end

---Iteratively creates directory at every level of the provided sub path.
---
---Returns success if path already exists and is a directory.
---@param subpath path path of dirs, relative to dir, to create
---@return nil Always nil
---@return string? Error message, if error
function htt.fs.Dir:make_path(subpath) end

---Open directory at `subpath`.
---@param subpath string path relative to dir of directory to open
---@return htt.fs.Dir directory Handle to the opened directory
---@return string? error Error message, if any
function htt.fs.Dir:open_dir(subpath) end

---Open parent directory.
---@return htt.fs.Dir directory Handle to the opened directory
---@return string? error Error message, if any
function htt.fs.Dir:parent() end

---Return iterator to loop over all items in directory.
---@return htt.fs.DirIterator it Iterator for iterating over all items in directory
---@return string? error Error message, if any
function htt.fs.Dir:list() end

---Return iterator for recursively iterating through all contents nested under dir.
---@return htt.fs.DirIterator it Iterator for recursively iterate over a directory
---@return string? error Error message, if any
function htt.fs.Dir:walk() end

---Remove item at subpath (or directory itself).
---
---For directories, this will recursively remove the directory itself and all its contents.
---@param subpath string? (optional) a path relative to this directory. Otherwise this directory.
---@return nil Unused
---@return string? error Error message, if any
function htt.fs.Dir:remove(subpath) end

---Return true if item at subpath, relative to directory, exists.
---@param subpath string? (optional) either check subpath relative to directory, or directory itself
---@return boolean True if an item at subpath exists
---@return string? error Error message, if any
function htt.fs.Dir:exists(subpath) end

---Create file at subpath, relative to directory.
---@param subpath string path of file to create, relative to directory
---@return nil Unused
---@return string? error Error message, if any
function htt.fs.Dir:touch(subpath) end

---Validate data through composable predicate functions describing the shape of data.
---
---You get to declaratively describe, through composable validation functions, the valid shape(s)
---of data, useful for constraining the data input (the model) to your templates.
---@class httIsModule
htt.is = {}


---Function used to determine if value conforms to some specification
---
---A validator function returns a pair of values, a boolean which is
---true iff the value conforms to the specification and (optionally)
---a string message, describing the issue if the value does not conform.
---@alias ValidatorFn fun (value: any): boolean, string?

---Function which, given a value returns true if test succeeds, false otherwise.
---@alias PredicateFn fun (value: any) boolean

---True iff. `value` is null.
---@param value any some input value to test
---@return boolean A boolean, true if the value was deemed valid
---@return string? Error message if validation failed
function htt.is.null(value) end

---True iff. `value` is a boolean.
---@param value any some input value to test
---@return boolean A boolean, true if the value was deemed valid
---@return string? Error message if validation failed
function htt.is.boolean(value) end

---True iff. `value` is a number.
---@param value any some input value to test
---@return boolean A boolean, true if the value was deemed valid
---@return string? Error message if validation failed
function htt.is.number(value) end

---True iff. `value` is a string.
---@param value any some input value to test
---@return boolean A boolean, true if the value was deemed valid
---@return string? Error message if validation failed
function htt.is.string(value) end

---True iff. `value` is a userdata object.
---userdata objects are raw blocks of memory created by an external language like C
---@param value any some input value to test
---@return boolean A boolean, true if the value was deemed valid
---@return string? Error message if validation failed
function htt.is.userdata(value) end

---True iff. `value` is a function.
---@param value any some input value to test
---@return boolean A boolean, true if the value was deemed valid
---@return string? Error message if validation failed
function htt.is.fn(value) end

---True iff. `value` is a function.
---@param value any some input value to test
---@return boolean A boolean, true if the value was deemed valid
---@return string? Error message if validation failed
function htt.is.callable(value) end

---True iff. `value` is a table.
---
---Note that tables can *also* be callable if they implement the __call metamethod
---@param value any some input value to test
---@return boolean A boolean, true if the value was deemed valid
---@return string? Error message if validation failed
function htt.is.table(value) end

---Returns a function which tests input value iff. not nil
---@param validator ValidatorFn a validate function like htt.is.null
---@return ValidatorFn Validator function
function htt.is.optional(validator) end

---Wraps `pred` and returns a validator function.
---@param pred PredicateFn a predicate function (a function taking a single argument and returning a bool)
---@param label string a label, used to the describe the kind of test `pred` performs, used in the error message if validation fails
---@return ValidatorFn Validator function
function htt.is.pred(pred, label) end

---Wraps the provided validator functions, returning a new validator which
---succeeds if any of the provided validators apply to the provided value.
---
---Read as: if any of these validator apply, the data is valid.
---@param ... ValidatorFn one or more validator functions to test again
---@return ValidatorFn Validator function
function htt.is.any(...) end

---Wraps the provided validator functions, returning a new validator which
---succeeds if all of the provided validators apply to the provided value.
---
---Read as: if all of these validators apply, the data is valid.
---@param ... ValidatorFn one or more validator functions to test again
---@return ValidatorFn Validator function
function htt.is.all(...) end

---Wraps the provided validator, returning a validator which succeeds if
---provided a list where each element is valid according to `validator`.
---@param validator ValidatorFn validator to apply to each element of the list
---@return ValidatorFn Validator function
function htt.is.list_of(validator) end

---Returns a validator which takes an input value and returns true if value is a table
---where for each entry in `spec`, there is a value which conforms to the corresponding validator
---
---Read as: I want to validate associative tables, I don't care about *all* their entries, but 
---         for some of the keys, I want to associate validator functions to constrain valid values.
---         An input value (a table) is valid if all entries constrained by a validator function in `spec`
---         succeed their validaton.
---@param spec table a table whose keys point to validator functions
---@return ValidatorFn Validator function
function htt.is.table_with(spec) end

---Returns a validator which succeeds if the input is a table whose keys all succeed when tested
---against `keyValidator` and whose values all succeed when tested against `valValidator`.
---@param keyValidator ValidatorFn validator to apply to each key
---@param valValidator ValidatorFn validator to apply to each value
---@return ValidatorFn Validator function
function htt.is.table_of(keyValidator, valValidator) end

---@class httJsonModule
htt.json = {}


---Deserialize `str` to a Lua value, converting values like so:
---
---*----------------*---------------------*
---| JSON           | Lua                 |
---*----------------*---------------------*
---| object         | table (associative) |
---| array          | table (list)        |
---| string         | string              |
---| number (int)   | integer             |
---| number (float) | number              |
---| true           | boolean             |
---| false          | boolean             |
---| null           | nil                 |
---*----------------*---------------------*
---@param str string a string of JSON
---@return any A Lua data-structure reflecting the deserialized JSON
function htt.json.loads(str) end

---Serialize `obj` to a JSON-formatted string.
---
---See the table in `loads` for information on how values are
---converted.
---@param obj any some Lua data-structure
---@return string A JSON-formatted string representing `obj`.
function htt.json.dumps(obj) end